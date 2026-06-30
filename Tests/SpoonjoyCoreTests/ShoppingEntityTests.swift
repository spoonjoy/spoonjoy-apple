import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Shopping App Entity contracts")
struct ShoppingEntityTests {
    @Test("shopping entity sources exist with AppIntents contracts")
    func shoppingEntitySourcesExistWithAppIntentsContracts() throws {
        var failures = shoppingSourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/ShoppingEntityCatalog.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/ShoppingEntityCatalog.swift": [
                    "ShoppingEntityCatalog",
                    "ShoppingEntityCatalogError",
                    "ShoppingEntityKind",
                    "ShoppingEntityTransferValue",
                    "ShoppingEntityScope",
                    "ShoppingListEntityDescriptor",
                    "ShoppingItemEntityDescriptor",
                    "ShoppingEntityIndexPurgePlan",
                    "isPlaceholder",
                    "shoppingListEntity()",
                    "shoppingItemEntity(id:",
                    "shoppingItemEntities(for identifiers:",
                    "shoppingItemEntities(matching string:",
                    "suggestedShoppingItemEntities",
                    "public static func loading(",
                    "loadSnapshot()",
                    "NativeSyncSnapshot",
                    "NativeSyncCachedRecord",
                    "NativeSyncEntryKind.shoppingItem",
                    "NativeSyncResourceType.shoppingItem",
                    "tombstones",
                    "accountID",
                    "environment",
                    "private static func scopedIdentifier(",
                    "public static func shoppingListEntityIdentifier(",
                    "public static func shoppingItemEntityIdentifier(",
                    "public static func resolvedShoppingItemID(",
                    "public static func purgeEntityIdentifiers(",
                    "purgeDomainIdentifiers(",
                    "SpotlightIndexPlan.shoppingListItemUniqueIdentifier",
                    "SpotlightIndexPlan.shoppingListItemDomainIdentifier",
                    "public static func accountScopePurge(",
                    "public static func tombstonePurge(",
                    "public static func cacheDeletePurge(",
                    "domainIdentifiers",
                    "ShoppingListState",
                    "ShoppingListItem",
                    "activeItems",
                    "deletedAt",
                    "checked",
                    "displayQuantity",
                    "AppRoute.shoppingList",
                    "NativeSharePayload.privateShoppingList",
                    "NativeSharePayload.privateShoppingItem",
                    "privateTransferValue",
                    "debugFields"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import CoreTransferable",
                    "import SpoonjoyCore",
                    "@available(iOS 27.0, macOS 27.0, *)",
                    "struct SpoonjoyShoppingListEntity: AppEntity",
                    "struct SpoonjoyShoppingItemEntity: AppEntity",
                    "struct SpoonjoyShoppingListEntityQuery: EntityQuery",
                    "struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery",
                    "typealias DefaultQuery = SpoonjoyShoppingListEntityQuery",
                    "typealias DefaultQuery = SpoonjoyShoppingItemEntityQuery",
                    "static let typeDisplayRepresentation",
                    "var displayRepresentation",
                    "DisplayRepresentation",
                    "TypeDisplayRepresentation",
                    "entities(for identifiers: [String]) async throws",
                    "entities(matching string: String) async throws",
                    "suggestedEntities() async throws",
                    "ShoppingEntityCatalog",
                    "ShoppingListEntityDescriptor",
                    "ShoppingItemEntityDescriptor",
                    "Transferable",
                    "TransferRepresentation",
                    "ShoppingEntityTransferValue",
                    "resolvedShoppingItemID() throws",
                    "NativeIntentActionError.unresolvedShoppingItemEntity",
                    "descriptor.isPlaceholder",
                    "NativeAppStateLocation.defaultFileURL()",
                    "FileBackedNativeSyncStore",
                    "loadSnapshot()",
                    "trustedIntentScope",
                    "KeychainTokenVault()",
                    "scope.accountID",
                    "scope.environment"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Shopping Item\", requestValueDialog:",
                    "var item: SpoonjoyShoppingItemEntity",
                    "try item.resolvedShoppingItemID()"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "SpoonjoyShoppingListEntity",
                    "SpoonjoyShoppingItemEntity",
                    "SpoonjoyShoppingListEntityQuery",
                    "SpoonjoyShoppingItemEntityQuery"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "shopping list App Entity",
                    "shopping item App Entity",
                    "ShoppingEntityCatalog",
                    "SpoonjoyShoppingListEntity",
                    "SpoonjoyShoppingItemEntity"
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "NativeShoppingEntityIndexPurgeOperation",
                    "NativeShoppingEntityIndexPurgeRequest",
                    "shoppingEntityIndexPurge",
                    "shoppingEntityPurgeRequests",
                    "performSettingsSessionOperation",
                    "ShoppingEntityIndexPurgePlan.accountScopePurge",
                    "ShoppingEntityCatalog.purgeEntityIdentifiers(",
                    "ShoppingEntityCatalog.purgeDomainIdentifiers(",
                    "purgeShoppingEntityIdentifiers",
                    "logout",
                    "revokeAndLogout",
                    "cacheEnvironment"
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    "bootstrapAndDrain",
                    "ShoppingEntityIndexPurgePlan.tombstonePurge",
                    "ShoppingEntityIndexPurgePlan.accountScopePurge",
                    "shoppingEntityAccountScopePurgePlan",
                    "shoppingEntityPurgeIdentifiers",
                    "shoppingEntityPurgeDomainIdentifiers",
                    "previousSnapshot",
                    "ShoppingEntityCatalog.purgeEntityIdentifiers(",
                    "ShoppingEntityCatalog.purgeDomainIdentifiers(",
                    "NativeSyncResourceType.shoppingItem",
                    "tombstones",
                    "removedCacheKeys"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    "accountID: String? = nil",
                    "environment: NativeCacheEnvironment? = nil",
                    "deleteSearchableItems(withIdentifiers:",
                    "deleteSearchableItems(withDomainIdentifiers:"
                ]
            ],
            forbiddenTokens: [
                "@Parameter(title: \"Item ID\")",
                "var itemID: String",
                "String-only shopping App Intent",
                "TODO Shopping AppEntity",
                "eventually add shopping entities"
            ]
        )
        failures.append(contentsOf: shoppingSourceBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "performSettingsSessionOperation",
                    pattern: #"func\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)"#,
                    requiredTokens: [
                        "case .logout, .revokeAndLogout",
                        "ShoppingEntityIndexPurgePlan.accountScopePurge",
                        "ShoppingEntityCatalog.purgeEntityIdentifiers(",
                        "ShoppingEntityCatalog.purgeDomainIdentifiers(",
                        "purgeShoppingEntityIdentifiers",
                        "cacheEnvironment"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "bootstrapFromLiveAPI consumes sync purge report",
                    pattern: #"func\s+bootstrapFromLiveAPI\(\s*session: AuthSession,\s*trigger: NativeSyncTriggerEvent\s*\)"#,
                    requiredTokens: [
                        "let report = try await syncTriggerCoordinator.handle(trigger)",
                        "report.shoppingEntityPurgeRequests"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    label: "foreground sync consumes sync purge report",
                    pattern: #"\.task\(id: contentState\.environment\.rawValue\)"#,
                    requiredTokens: [
                        "let report = try? await syncTriggerCoordinator.handle(.foreground)",
                        "report.shoppingEntityPurgeRequests",
                        "purgeShoppingEntityIndexesHandler"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                    label: "bootstrapAndDrain scoped tombstone purge",
                    pattern: #"public\s+func\s+bootstrapAndDrain\(\s*configuration: APIClientConfiguration,\s*trigger: NativeCacheRevalidationTrigger,\s*scope: NativeSyncExecutionScope\s*\)"#,
                    requiredTokens: [
                        "case .success(let cursor, let tombstones)",
                        "ShoppingEntityIndexPurgePlan.tombstonePurge",
                        "shoppingEntityAccountScopePurgePlan",
                        "shoppingEntityPurgeIdentifiers",
                        "shoppingEntityPurgeDomainIdentifiers",
                        "previousSnapshot",
                        "ShoppingEntityCatalog.purgeEntityIdentifiers(",
                        "ShoppingEntityCatalog.purgeDomainIdentifiers(",
                        "NativeSyncResourceType.shoppingItem",
                        "removedCacheKeys"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("shopping entities resolve from scoped native sync cache records")
    func shoppingEntitiesResolveFromScopedNativeSyncCacheRecords() async throws {
        let catalog = try Self.shoppingCatalog()
        let list = try await catalog.shoppingListEntity()

        #expect(list.id == ShoppingEntityCatalog.shoppingListEntityIdentifier(accountID: "account_ari", environment: .production))
        #expect(list.scope == ShoppingEntityScope(accountID: "account_ari", environment: .production))
        #expect(list.title == "Shopping List")
        #expect(list.subtitle == "3 active items")
        #expect(list.disambiguationLabel == "Shopping List for ari")
        #expect(list.route == .shoppingList)
        #expect(list.activeItemCount == 3)
        #expect(list.transferValue.kind == .shoppingList)
        #expect(list.transferValue.title == "Shopping List")
        #expect(list.transferValue.routeIdentifier == AppRoute.shoppingList.stateIdentifier)
        #expect(list.transferValue.publicURL == nil)
        #expect(list.transferValue.privateTransferValue.contains("shopping-list"))
        #expect(list.transferValue.debugFields.isEmpty)

        let lemons = try await catalog.shoppingItemEntity(id: "item_lemons")
        #expect(lemons.id == ShoppingEntityCatalog.shoppingItemEntityIdentifier(itemID: "item_lemons", accountID: "account_ari", environment: .production))
        #expect(lemons.itemID == "item_lemons")
        #expect(lemons.scope == ShoppingEntityScope(accountID: "account_ari", environment: .production))
        #expect(lemons.title == "lemons")
        #expect(lemons.subtitle == "2 each")
        #expect(lemons.disambiguationLabel == "lemons in Shopping List")
        #expect(lemons.route == .shoppingList)
        #expect(!lemons.checked)
        #expect(lemons.transferValue.kind == .shoppingItem)
        #expect(lemons.transferValue.rawResourceID == "item_lemons")
        #expect(lemons.transferValue.routeIdentifier == AppRoute.shoppingList.stateIdentifier)
        #expect(lemons.transferValue.publicURL == nil)
        #expect(lemons.transferValue.privateTransferValue.contains("shopping-item"))
        #expect(lemons.transferValue.debugFields.isEmpty)
        #expect(try ShoppingEntityCatalog.resolvedShoppingItemID(from: lemons.id, accountID: "account_ari", environment: .production) == "item_lemons")

        let matches = try await catalog.shoppingItemEntities(matching: "  lemon  ")
        #expect(matches.map(\.itemID) == ["item_lemons"])

        let suggested = try await catalog.suggestedShoppingItemEntities(limit: 10)
        #expect(suggested.map(\.itemID) == ["item_lemons", "item_spaghetti", "item_parmesan"])

        let byIdentifier = try await catalog.shoppingItemEntities(for: [suggested[1].id, suggested[0].id])
        #expect(byIdentifier.map(\.itemID) == ["item_spaghetti", "item_lemons"])

        let rawIdentifierBatch = try await catalog.shoppingItemEntities(for: ["item_lemons"])
        #expect(rawIdentifierBatch.isEmpty)
    }

    @Test("shopping entity lookup uses supplied sync snapshot records instead of fixture fallback")
    func shoppingEntityLookupUsesSuppliedSyncSnapshotRecordsInsteadOfFixtureFallback() async throws {
        let saffron = Self.shoppingItem(
            id: "item_saffron",
            name: "saffron",
            quantity: 1,
            unit: "pinch",
            sortIndex: 0
        )
        let catalog = try Self.shoppingCatalog(items: [saffron])

        let suggested = try await catalog.suggestedShoppingItemEntities(limit: 10)
        #expect(suggested.map(\.itemID) == ["item_saffron"])
        #expect(suggested.first?.title == "saffron")
        #expect(suggested.first?.subtitle == "1 pinch")

        let matches = try await catalog.shoppingItemEntities(matching: "saff")
        #expect(matches.map(\.itemID) == ["item_saffron"])

        let fixtureMatches = try await catalog.shoppingItemEntities(matching: "lemons")
        #expect(fixtureMatches.isEmpty)
    }

    @Test("shopping entity lookup filters deleted, tombstoned, and wrong-scope data")
    func shoppingEntityLookupFiltersDeletedTombstonedAndWrongScopeData() async throws {
        let catalog = try Self.shoppingCatalog(
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .shoppingItem,
                    resourceID: "item_spaghetti",
                    parentResourceID: nil,
                    title: "spaghetti",
                    deletedAt: "2026-06-01T00:10:00.000Z",
                    updatedAt: "2026-06-01T00:10:00.000Z"
                ),
                NativeSyncTombstone(
                    resourceType: .recipe,
                    resourceID: "recipe_not_a_shopping_item",
                    parentResourceID: nil,
                    title: "Not a shopping item",
                    deletedAt: "2026-06-01T00:11:00.000Z",
                    updatedAt: "2026-06-01T00:11:00.000Z"
                )
            ]
        )

        let suggested = try await catalog.suggestedShoppingItemEntities(limit: 10)
        #expect(suggested.map(\.itemID) == ["item_lemons", "item_parmesan"])

        let deletedMatches = try await catalog.shoppingItemEntities(matching: "basil")
        #expect(deletedMatches.isEmpty)

        let tombstonedMatches = try await catalog.shoppingItemEntities(matching: "spaghetti")
        #expect(tombstonedMatches.isEmpty)

        let wrongAccountCatalog = try Self.shoppingCatalog(currentAccountID: "account_other")
        let wrongEnvironmentCatalog = try Self.shoppingCatalog(environment: .local)

        #expect(try await wrongAccountCatalog.suggestedShoppingItemEntities(limit: 10).isEmpty)
        #expect(try await wrongEnvironmentCatalog.suggestedShoppingItemEntities(limit: 10).isEmpty)
        #expect(try await wrongAccountCatalog.shoppingItemEntities(matching: "lemon").isEmpty)
        #expect(try await wrongEnvironmentCatalog.shoppingItemEntities(matching: "lemon").isEmpty)

        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.shoppingListEntity()
        }
        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.shoppingItemEntity(id: "item_lemons")
        }
        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.shoppingListEntity()
        }
        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.shoppingItemEntity(id: "item_lemons")
        }

        let wrongScopedID = ShoppingEntityCatalog.shoppingItemEntityIdentifier(
            itemID: "item_lemons",
            accountID: "account_other",
            environment: .production
        )
        let wrongScopedBatch = try await catalog.shoppingItemEntities(for: [wrongScopedID])
        #expect(wrongScopedBatch.isEmpty)
    }

    @Test("shopping entity transfer values filter private and debug-only fields")
    func shoppingEntityTransferValuesFilterPrivateAndDebugOnlyFields() async throws {
        let catalog = try Self.shoppingCatalog()
        let list = try await catalog.shoppingListEntity()
        let lemons = try await catalog.shoppingItemEntity(id: "item_lemons")
        let serializedValues = [
            list.transferValue.privateTransferValue,
            lemons.transferValue.privateTransferValue,
            list.transferValue.userVisibleSummary,
            lemons.transferValue.userVisibleSummary
        ].joined(separator: "\n")

        for forbidden in [
            "account_ari",
            NativeCacheEnvironment.production.rawValue,
            "categoryKey",
            "iconKey",
            "checkedAt",
            "deletedAt",
            "provider",
            "conflict",
            "debug"
        ] {
            #expect(!serializedValues.localizedCaseInsensitiveContains(forbidden), "\(forbidden) leaked into shopping transfer value")
        }

        #expect(list.transferValue.debugFields.isEmpty)
        #expect(lemons.transferValue.debugFields.isEmpty)
        #expect(list.transferValue.publicURL == nil)
        #expect(lemons.transferValue.publicURL == nil)
    }

    @Test("shopping entity coverage edges preserve placeholder loading and identifier behavior")
    func shoppingEntityCoverageEdgesPreservePlaceholderLoadingAndIdentifierBehavior() async throws {
        #expect(ShoppingListEntityDescriptor.placeholder.isPlaceholder)
        #expect(ShoppingItemEntityDescriptor.placeholder.isPlaceholder)
        #expect(ShoppingEntityScope(accountID: "account_ari", environment: .production).domainIdentifier == "shopping:production:schema2:account_ari")
        #expect(NativeIntentActionError.unresolvedShoppingItemEntity.description == "Choose a Spoonjoy shopping item before running this Siri action.")

        let emptyCatalog = try Self.shoppingCatalog(items: [])
        let emptyList = try await emptyCatalog.shoppingListEntity()
        #expect(!emptyList.isPlaceholder)
        #expect(emptyList.subtitle == "0 active items")
        #expect(emptyList.transferValue.userVisibleSummary == "0 active items")
        #expect(try await emptyCatalog.shoppingItemEntities(matching: " ").isEmpty)
        #expect(try await emptyCatalog.suggestedShoppingItemEntities(limit: -1).isEmpty)

        let oil = Self.shoppingItem(
            id: "item_oil",
            name: "oil",
            quantity: nil,
            unit: nil,
            sortIndex: 0
        )
        let oneItemCatalog = try Self.shoppingCatalog(items: [oil])
        let oneItemList = try await oneItemCatalog.shoppingListEntity()
        #expect(oneItemList.subtitle == "1 active item")
        let oilEntityID = ShoppingEntityCatalog.shoppingItemEntityIdentifier(
            itemID: "item_oil",
            accountID: "account_ari",
            environment: .production
        )
        let oilEntity = try await oneItemCatalog.shoppingItemEntity(id: oilEntityID)
        #expect(!oilEntity.isPlaceholder)
        #expect(oilEntity.transferValue.userVisibleSummary == "oil")

        let tiedCatalog = try Self.shoppingCatalog(items: [
            Self.shoppingItem(id: "item_b", name: "basil", quantity: 1, unit: "bunch", sortIndex: 0),
            Self.shoppingItem(id: "item_a", name: "apples", quantity: 2, unit: "each", sortIndex: 0)
        ])
        #expect(try await tiedCatalog.suggestedShoppingItemEntities(limit: 10).map(\.itemID) == ["item_a", "item_b"])
        #expect(try await tiedCatalog.shoppingItemEntities(matching: "each").map(\.itemID) == ["item_a"])

        let loadedStore = InMemoryNativeSyncStore(
            accountID: "account_ari",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "shopping-load-global"),
                shoppingCursor: ShoppingSyncCursor(rawValue: "shopping-load-shopping"),
                updatedAt: "2026-06-01T01:00:00.000Z"
            ),
            queue: NativeMutationQueue(),
            cachedRecords: try [oil].map { item in
                NativeSyncCachedRecord(
                    kind: .shoppingItem,
                    resourceID: item.id,
                    payload: try Self.shoppingJSONValue(item),
                    serverRevision: .updatedAt(item.updatedAt)
                )
            }
        )
        let loadedCatalog = try await ShoppingEntityCatalog.loading(
            syncStore: loadedStore,
            currentAccountID: "account_ari",
            environment: .production
        )
        #expect(try await loadedCatalog.suggestedShoppingItemEntities().map(\.itemID) == ["item_oil"])

        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await oneItemCatalog.shoppingItemEntity(id: "item_missing")
        }
        await shoppingExpectAsyncThrows(ShoppingEntityCatalogError.self) {
            _ = try await oneItemCatalog.shoppingItemEntity(id: "../item_oil")
        }
    }

    @Test("shopping entity purge plans cover logout account-switch cache-delete and tombstones")
    func shoppingEntityPurgePlansCoverLogoutAccountSwitchCacheDeleteAndTombstones() throws {
        let scope = ShoppingEntityScope(accountID: "account_ari", environment: .production)
        let spotlightScope = SpotlightIndexScope(accountID: scope.accountID, environment: scope.environment)
        let logoutPlan = ShoppingEntityIndexPurgePlan.accountScopePurge(
            accountID: scope.accountID,
            environment: scope.environment,
            shoppingItemIDs: ["item_lemons", "item_spaghetti"]
        )

        #expect(logoutPlan.identifiers == [
            SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_lemons", scope: spotlightScope),
            SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_spaghetti", scope: spotlightScope)
        ])
        #expect(logoutPlan.domainIdentifiers == [
            SpotlightIndexPlan.shoppingListItemDomainIdentifier(scope: spotlightScope)
        ])
        #expect(logoutPlan.reason == .accountScopeChanged)
        #expect(SpotlightIndexPlan.document(
            shoppingListItem: Self.shoppingItem(id: "item_lemons", name: "lemons", quantity: 2, unit: "each", sortIndex: 0),
            scope: spotlightScope
        ).uniqueIdentifier == logoutPlan.identifiers.first)
        #expect(SpotlightIndexPlan.document(
            shoppingListItem: Self.shoppingItem(id: "item_lemons", name: "lemons", quantity: 2, unit: "each", sortIndex: 0),
            scope: spotlightScope
        ).domainIdentifier == logoutPlan.domainIdentifiers.first)

        let cacheDeletePlan = ShoppingEntityIndexPurgePlan.cacheDeletePurge(
            accountID: scope.accountID,
            environment: scope.environment,
            shoppingItemIDs: ["item_parmesan"]
        )
        #expect(cacheDeletePlan.identifiers == [
            SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_parmesan", scope: spotlightScope)
        ])
        #expect(cacheDeletePlan.domainIdentifiers.isEmpty)
        #expect(cacheDeletePlan.reason == .cacheDeleted)

        let tombstonePlan = ShoppingEntityIndexPurgePlan.tombstonePurge(
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .shoppingItem,
                    resourceID: "item_lemons",
                    parentResourceID: nil,
                    title: "lemons",
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
            SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_lemons", scope: spotlightScope)
        ])
        #expect(tombstonePlan.domainIdentifiers.isEmpty)
        #expect(tombstonePlan.reason == .tombstoneApplied)

        #expect(ShoppingEntityCatalog.username(from: "chef_ari") == "chef_ari")
        #expect(ShoppingEntityCatalog.purgeEntityIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: ShoppingEntityIndexPurgePlan(
                identifiers: [ShoppingEntityCatalog.shoppingItemEntityIdentifier(
                    itemID: "item_lemons",
                    accountID: scope.accountID,
                    environment: scope.environment
                )],
                domainIdentifiers: ["app.spoonjoy.production.other.shopping-list-item"],
                reason: .cacheDeleted
            )
        ).isEmpty)
        #expect(ShoppingEntityCatalog.purgeDomainIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: ShoppingEntityIndexPurgePlan(
                identifiers: [],
                domainIdentifiers: ["app.spoonjoy.production.other.shopping-list-item"],
                reason: .accountScopeChanged
            )
        ).isEmpty)
    }

    private static func shoppingCatalog(
        currentAccountID: String = "account_ari",
        environment: NativeCacheEnvironment = .production,
        items: [ShoppingListItem]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> ShoppingEntityCatalog {
        ShoppingEntityCatalog(
            syncSnapshot: try syncSnapshot(items: items, tombstones: tombstones),
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    private static func syncSnapshot(
        items: [ShoppingListItem]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> NativeSyncSnapshot {
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let cachedItems = items ?? shoppingList.items
        return NativeSyncSnapshot(
            accountID: "account_ari",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "shopping-entity-global-cursor"),
                shoppingCursor: ShoppingSyncCursor(rawValue: "shopping-entity-shopping-cursor"),
                updatedAt: shoppingList.updatedAt
            ),
            queue: NativeMutationQueue(),
            cachedRecords: try cachedItems.map { item in
                NativeSyncCachedRecord(
                    kind: .shoppingItem,
                    resourceID: item.id,
                    payload: try shoppingJSONValue(item),
                    serverRevision: .updatedAt(item.updatedAt)
                )
            },
            tombstones: tombstones
        )
    }

    private static func shoppingJSONValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    private static func shoppingItem(
        id: String,
        name: String,
        quantity: Double?,
        unit: String?,
        sortIndex: Int
    ) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: "custom",
            iconKey: "ingredient",
            sortIndex: sortIndex,
            updatedAt: "2026-06-01T01:00:00.000Z"
        )
    }
}

private func shoppingSourceContractFailures(
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
        let uncommented = shoppingUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }

    return failures
}

private func shoppingSourceBodyContractFailures(
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
        let uncommented = shoppingUncommentedSwift(content)
        guard let body = shoppingDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func shoppingDeclarationBody(in content: String, pattern: String) -> String? {
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

private func shoppingUncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}

private func shoppingExpectAsyncThrows<E: Error>(
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
