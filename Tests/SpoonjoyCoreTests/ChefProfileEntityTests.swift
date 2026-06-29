import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Chef profile App Entity contracts")
struct ChefProfileEntityTests {
    @Test("chef profile entity sources exist with AppIntents contracts")
    func chefProfileEntitySourcesExistWithAppIntentsContracts() throws {
        let failures = chefProfileSourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/ChefProfileEntityCatalog.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/ChefProfileEntityCatalog.swift": [
                    "ChefProfileEntityCatalog",
                    "ChefProfileEntityCatalogError",
                    "ChefProfileEntityKind",
                    "ChefProfileEntityTransferValue",
                    "ChefProfileEntityScope",
                    "ChefProfileEntityDescriptor",
                    "isPlaceholder",
                    "chefProfileEntity(id:",
                    "chefProfileEntities(for identifiers:",
                    "chefProfileEntities(matching string:",
                    "suggestedChefProfileEntities",
                    "public static func loading(",
                    "NativeSyncSnapshot",
                    "NativeSyncCachedRecord",
                    "NativeSyncTombstone",
                    "tombstones",
                    "NativeSyncEntryKind.profile",
                    "NativeSyncEntryKind.recipe",
                    "NativeDurableCacheSnapshot",
                    "NativeDurableCacheStore",
                    "NativeCachePayload.profile",
                    "accountID",
                    "environment",
                    "ProfileSurfaceResult",
                    "ProfileSurfaceData",
                    "ProfileSummary",
                    "ProfileGraphPage",
                    "ProfileGraphRow",
                    "ProfileGraphDirection.fellowChefs",
                    "ProfileGraphDirection.kitchenVisitors",
                    "interactionSummary",
                    "fellowChefs",
                    "kitchenVisitors",
                    "public static func resolvedChefProfileID(",
                    "AppRoute.profile",
                    "DeepLinkURLBuilder.url(for:",
                    "canonicalURL",
                    "transferValue",
                    "debugFields"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import CoreTransferable",
                    "import SpoonjoyCore",
                    "@available(iOS 27.0, macOS 27.0, *)",
                    "struct SpoonjoyChefProfileEntity: AppEntity",
                    "struct SpoonjoyChefProfileEntityQuery: EntityQuery, EntityStringQuery",
                    "typealias DefaultQuery = SpoonjoyChefProfileEntityQuery",
                    "static let typeDisplayRepresentation",
                    "var displayRepresentation",
                    "DisplayRepresentation",
                    "TypeDisplayRepresentation",
                    "entities(for identifiers: [String]) async throws",
                    "entities(matching string: String) async throws",
                    "suggestedEntities() async throws",
                    "ChefProfileEntityCatalog",
                    "ChefProfileEntityDescriptor",
                    "Transferable",
                    "TransferRepresentation",
                    "ChefProfileEntityTransferValue",
                    "resolvedChefProfileID() throws",
                    "NativeIntentActionError.unresolvedChefProfileEntity",
                    "descriptor.isPlaceholder",
                    "DeepLinkURLBuilder.url(for:",
                    "NativeAppStateLocation.defaultFileURL()",
                    "FileBackedNativeSyncStore",
                    "NativeDurableCacheStore",
                    "trustedIntentScope",
                    "KeychainTokenVault()",
                    "scope.accountID",
                    "scope.environment"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "SpoonjoyChefProfileEntity",
                    "SpoonjoyChefProfileEntityQuery"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "chef profile App Entity",
                    "ChefProfileEntityCatalog",
                    "SpoonjoyChefProfileEntity"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "unresolvedChefProfileEntity",
                    "Choose a Spoonjoy chef profile before running this Siri action."
                ]
            ],
            forbiddenTokens: [
                "@Parameter(title: \"Chef ID\")",
                "@Parameter(title: \"Profile ID\")",
                "var chefID: String",
                "var profileID: String",
                "String-only chef profile App Intent",
                "SpoonjoyFollowEntity",
                "FollowEntity",
                "comment App Entity",
                "feed App Entity",
                "message App Entity",
                "mail App Entity",
                "privateTransferValue",
                "TODO ChefProfile AppEntity",
                "eventually add chef profile entities"
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("chef profile entities resolve cached profiles and expose public transfer values")
    func chefProfileEntitiesResolveCachedProfilesAndExposePublicTransferValues() async throws {
        let catalog = try Self.catalog()

        let ariByUsername = try await catalog.chefProfileEntity(id: "  ari  ")
        let ariByID = try await catalog.chefProfileEntity(id: "chef_ari")

        #expect(ariByUsername == ariByID)
        #expect(ariByUsername.id == "chef_ari")
        #expect(ariByUsername.profileID == "chef_ari")
        #expect(ariByUsername.username == "ari")
        #expect(ariByUsername.title == "ari")
        #expect(ariByUsername.subtitle == "Joined Jun 2026")
        #expect(ariByUsername.disambiguationLabel == "ari on Spoonjoy")
        #expect(ariByUsername.route == .profile(identifier: "ari"))
        #expect(ariByUsername.canonicalURL == URL(string: "https://spoonjoy.app/users/ari"))
        #expect(ariByUsername.photoURL == URL(string: "https://spoonjoy.app/photos/profiles/chef_ari/avatar.jpg"))
        #expect(ariByUsername.fellowChefsCount == 1)
        #expect(ariByUsername.kitchenVisitorsCount == 1)
        #expect(ariByUsername.interactionSummary == nil)
        #expect(!ariByUsername.isPlaceholder)

        let transfer = ariByUsername.transferValue
        #expect(transfer.kind == .chefProfile)
        #expect(transfer.profileID == "chef_ari")
        #expect(transfer.username == "ari")
        #expect(transfer.title == "ari")
        #expect(transfer.routeIdentifier == AppRoute.profile(identifier: "ari").stateIdentifier)
        #expect(transfer.canonicalURL == ariByUsername.canonicalURL)
        #expect(transfer.photoURL == ariByUsername.photoURL)
        #expect(transfer.userVisibleSummary == "ari on Spoonjoy")
        #expect(transfer.debugFields.isEmpty)
        #expect(try ChefProfileEntityCatalog.resolvedChefProfileID(from: transfer.profileID) == "chef_ari")

        let serializedTransfer = String(decoding: try JSONEncoder().encode(transfer), as: UTF8.self)
        for forbidden in ["account_ari", "environment", "isOwner", "serverRevision", "cache", "score", "metadata", "token", "provider-secret", "debugSecret"] {
            #expect(!serializedTransfer.contains(forbidden))
        }

        let matches = try await catalog.chefProfileEntities(matching: "  ari  ")
        #expect(matches.map(\.profileID) == ["chef_ari"])

        let byIdentifier = try await catalog.chefProfileEntities(for: ["chef_jules", "chef_missing_from_old_donation", "chef_ari"])
        #expect(byIdentifier.map(\.profileID) == ["chef_jules", "chef_ari"])
    }

    @Test("chef profile suggestions include graph chefs without follow feed or comment semantics")
    func chefProfileSuggestionsIncludeGraphChefsWithoutFollowFeedOrCommentSemantics() async throws {
        let catalog = try Self.catalog()
        let suggested = try await catalog.suggestedChefProfileEntities(limit: 10)

        #expect(suggested.map(\.profileID) == ["chef_ari", "chef_jules", "chef_mika"])
        #expect(suggested.map(\.route) == [
            .profile(identifier: "ari"),
            .profile(identifier: "jules"),
            .profile(identifier: "mika")
        ])

        let jules = try #require(suggested.first { $0.profileID == "chef_jules" })
        #expect(jules.username == "jules")
        #expect(jules.subtitle == "Fellow chef - 1 spoon")
        #expect(jules.interactionSummary == "1 spoon")
        #expect(jules.transferValue.userVisibleSummary == "jules on Spoonjoy")

        let mika = try #require(suggested.first { $0.profileID == "chef_mika" })
        #expect(mika.username == "mika")
        #expect(mika.subtitle == "Kitchen visitor - 1 spoon")
        #expect(mika.interactionSummary == "1 spoon")

        let visibleText = suggested
            .flatMap { [$0.subtitle, $0.disambiguationLabel, $0.interactionSummary, $0.transferValue.userVisibleSummary] }
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        for forbidden in ["follow", "follower", "comment", "feed", "message", "mail"] {
            #expect(!visibleText.contains(forbidden))
        }
    }

    @Test("chef profile entities filter tombstoned profiles and recipe graph sources")
    func chefProfileEntitiesFilterTombstonedProfilesAndRecipeGraphSources() async throws {
        let catalog = try Self.catalog(syncSnapshot: Self.syncSnapshot(tombstones: [
            NativeSyncTombstone(
                resourceType: .profile,
                resourceID: "chef_jules",
                parentResourceID: nil,
                title: "jules",
                deletedAt: "2026-06-29T01:00:00.000Z",
                updatedAt: "2026-06-29T01:00:00.000Z"
            ),
            NativeSyncTombstone(
                resourceType: .recipe,
                resourceID: "recipe_ari_bread",
                parentResourceID: nil,
                title: "Ari Bread",
                deletedAt: "2026-06-29T01:00:00.000Z",
                updatedAt: "2026-06-29T01:00:00.000Z"
            )
        ]))

        #expect(try await catalog.suggestedChefProfileEntities(limit: 10).map(\.profileID) == ["chef_ari"])
        #expect(try await catalog.chefProfileEntities(matching: "jules").isEmpty)
        #expect(try await catalog.chefProfileEntities(matching: "mika").isEmpty)
        #expect(try await catalog.chefProfileEntities(for: ["chef_jules", "mika"]).isEmpty)

        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await catalog.chefProfileEntity(id: "jules")
        }
        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await catalog.chefProfileEntity(id: "mika")
        }
    }

    @Test("chef profile graph page rows honor profile tombstones")
    func chefProfileGraphPageRowsHonorProfileTombstones() async throws {
        let catalog = try Self.catalog(syncSnapshot: Self.syncSnapshot(
            records: try [
                Self.profileRecord(id: "chef_ari", username: "ari"),
                Self.profileGraphRecord(
                    id: "graph_fellow_chefs",
                    direction: .fellowChefs,
                    rows: [
                        Self.graphRow(
                            chefID: "chef_peer",
                            username: "peer",
                            spoons: 1,
                            forks: 0,
                            cookbookSaves: 0,
                            latestInteractionAt: "2026-06-29T00:06:00.000Z"
                        )
                    ]
                )
            ],
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .profile,
                    resourceID: "chef_peer",
                    parentResourceID: nil,
                    title: "peer",
                    deletedAt: "2026-06-29T01:00:00.000Z",
                    updatedAt: "2026-06-29T01:00:00.000Z"
                )
            ]
        ))

        #expect(try await catalog.suggestedChefProfileEntities(limit: 10).map(\.profileID) == ["chef_ari"])
        #expect(try await catalog.chefProfileEntities(matching: "peer").isEmpty)
        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await catalog.chefProfileEntity(id: "peer")
        }
    }

    @Test("chef profile entities decode profile payload variants and graph pages")
    func chefProfileEntitiesDecodeProfilePayloadVariantsAndGraphPages() async throws {
        let records = try [
            Self.profileResultRecord(
                id: "chef_result",
                username: "result",
                joinedLabel: "Joined Result",
                photoURL: URL(string: "https://spoonjoy.app/photos/profiles/chef_result/avatar.jpg"),
                fellowChefsCount: 2,
                kitchenVisitorsCount: 3
            ),
            Self.profileSummaryRecord(id: "chef_summary", username: "summary"),
            Self.rawProfileRecord(
                id: "chef_raw",
                username: "raw-chef",
                joinedLabel: "Joined Raw",
                photoURLRaw: "https://spoonjoy.app/photos/profiles/chef_raw/avatar.jpg"
            ),
            Self.rawProfileRecord(id: "chef_default", username: "default-chef", joinedLabel: "   "),
            Self.rawProfileRecord(id: "", username: "unsafe/profile"),
            Self.profileGraphRecord(
                id: "graph_kitchen_visitors",
                direction: .kitchenVisitors,
                rows: [
                    Self.graphRow(
                        chefID: "chef_zero",
                        username: "zero",
                        spoons: 0,
                        forks: 0,
                        cookbookSaves: 0,
                        latestInteractionAt: nil
                    ),
                    Self.graphRow(
                        chefID: "chef_active",
                        username: "active",
                        spoons: 2,
                        forks: 1,
                        cookbookSaves: 1,
                        latestInteractionAt: "2026-06-29T00:05:00.000Z"
                    )
                ]
            ),
            Self.profileGraphRecord(
                id: "graph_fellow_chefs",
                direction: .fellowChefs,
                rows: [
                    Self.graphRow(
                        chefID: "chef_peer",
                        username: "peer",
                        spoons: 1,
                        forks: 0,
                        cookbookSaves: 0,
                        latestInteractionAt: "2026-06-29T00:06:00.000Z"
                    )
                ]
            )
        ]
        let catalog = try Self.catalog(
            syncSnapshot: Self.syncSnapshot(records: records),
            cacheSnapshot: Self.cacheSnapshot(records: [
                Self.profileCacheRecord(id: "chef_zero", username: "zero")
            ])
        )

        let allMatches = try await catalog.chefProfileEntities(matching: "   ")
        #expect(allMatches.map(\.profileID) == [
            "chef_result",
            "chef_summary",
            "chef_raw",
            "chef_default",
            "chef_zero",
            "chef_active",
            "chef_peer"
        ])
        #expect(try await catalog.suggestedChefProfileEntities(limit: -1).isEmpty)

        let result = try await catalog.chefProfileEntity(id: "result")
        #expect(result.fellowChefsCount == 2)
        #expect(result.kitchenVisitorsCount == 3)
        #expect(result.subtitle == "Joined Result")
        #expect(result.photoURL == URL(string: "https://spoonjoy.app/photos/profiles/chef_result/avatar.jpg"))

        let summary = try await catalog.chefProfileEntity(id: "chef_summary")
        #expect(summary.username == "summary")
        #expect(summary.route == .profile(identifier: "summary"))

        let raw = try await catalog.chefProfileEntity(id: "raw-chef")
        #expect(raw.profileID == "chef_raw")
        #expect(raw.subtitle == "Joined Raw")
        #expect(raw.photoURL == URL(string: "https://spoonjoy.app/photos/profiles/chef_raw/avatar.jpg"))

        let rawDefault = try await catalog.chefProfileEntity(id: "default-chef")
        #expect(rawDefault.subtitle == "Joined Spoonjoy")
        #expect(rawDefault.photoURL == nil)

        let zero = try await catalog.chefProfileEntity(id: "zero")
        #expect(zero.subtitle == "Kitchen visitor - No interactions yet")
        #expect(zero.interactionSummary == nil)

        let active = try await catalog.chefProfileEntity(id: "active")
        #expect(active.subtitle == "Kitchen visitor - 2 spoons, 1 fork, 1 cookbook save")
        #expect(active.interactionSummary == "2 spoons, 1 fork, 1 cookbook save")

        let peer = try await catalog.chefProfileEntity(id: "peer")
        #expect(peer.subtitle == "Fellow chef - 1 spoon")
        #expect(peer.interactionSummary == "1 spoon")

        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await catalog.chefProfileEntity(id: "unsafe/profile")
        }
    }

    @Test("chef profile recipe graph suggestions sort ties use fallback timestamps and require an owner")
    func chefProfileRecipeGraphSuggestionsSortTiesUseFallbackTimestampsAndRequireAnOwner() async throws {
        let ari = Self.chef(id: "chef_ari", username: "ari")
        let ada = Self.chef(id: "chef_ada", username: "ada")
        let bob = Self.chef(id: "chef_bob", username: "bob")
        let cal = Self.chef(id: "chef_cal", username: "cal")
        let records = try [
            Self.profileRecord(id: "chef_ari", username: "ari"),
            Self.recipeRecord(Self.recipe(
                id: "recipe_ada",
                title: "Ada Soup",
                chef: ada,
                recentSpoons: [
                    Self.spoon(
                        id: "spoon_ari_ada",
                        recipeID: "recipe_ada",
                        chef: ari,
                        cookedAt: nil,
                        updatedAt: "2026-06-29T00:03:00.000Z"
                    )
                ]
            )),
            Self.recipeRecord(Self.recipe(
                id: "recipe_bob",
                title: "Bob Bread",
                chef: bob,
                recentSpoons: [
                    Self.spoon(
                        id: "spoon_ari_bob",
                        recipeID: "recipe_bob",
                        chef: ari,
                        cookedAt: "2026-06-29T00:03:00.000Z"
                    )
                ]
            )),
            Self.recipeRecord(Self.recipe(
                id: "recipe_cal",
                title: "Cal Curry",
                chef: cal,
                recentSpoons: [
                    Self.spoon(
                        id: "spoon_ari_cal",
                        recipeID: "recipe_cal",
                        chef: ari,
                        cookedAt: "2026-06-29T00:05:00.000Z"
                    )
                ]
            ))
        ]
        let catalog = try Self.catalog(syncSnapshot: Self.syncSnapshot(records: records))

        #expect(try await catalog.suggestedChefProfileEntities(limit: 10).map(\.profileID) == [
            "chef_ari",
            "chef_cal",
            "chef_ada",
            "chef_bob"
        ])
        #expect(try await catalog.chefProfileEntity(id: "ada").interactionSummary == "1 spoon")

        let nonOwnerCatalog = try Self.catalog(syncSnapshot: Self.syncSnapshot(records: try [
            Self.profileRecord(id: "chef_jules", username: "jules"),
            Self.recipeRecord(Self.recipe(
                id: "recipe_cal_without_owner",
                title: "Cal Curry",
                chef: cal,
                recentSpoons: [
                    Self.spoon(
                        id: "spoon_jules_cal",
                        recipeID: "recipe_cal_without_owner",
                        chef: Self.chef(id: "chef_jules", username: "jules"),
                        cookedAt: "2026-06-29T00:05:00.000Z"
                    )
                ]
            ))
        ]))
        #expect(try await nonOwnerCatalog.suggestedChefProfileEntities(limit: 10).map(\.profileID) == ["chef_jules"])
    }

    @Test("chef profile entities filter wrong scopes reject unsafe identifiers and load stores")
    func chefProfileEntitiesFilterWrongScopesRejectUnsafeIdentifiersAndLoadStores() async throws {
        let syncSnapshot = try Self.syncSnapshot()
        let cacheSnapshot = try Self.cacheSnapshot(records: [
            Self.profileCacheRecord(id: "chef_cached", username: "cached"),
            Self.emptyProfileCacheRecord(id: "chef_empty")
        ])
        let wrongAccountCatalog = ChefProfileEntityCatalog(
            syncSnapshot: syncSnapshot,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: "account_other",
            environment: .production
        )
        let wrongEnvironmentCatalog = ChefProfileEntityCatalog(
            syncSnapshot: syncSnapshot,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: "account_ari",
            environment: .local
        )

        #expect(try await wrongAccountCatalog.suggestedChefProfileEntities(limit: 10).isEmpty)
        #expect(try await wrongAccountCatalog.chefProfileEntities(for: ["chef_ari"]).isEmpty)
        #expect(try await wrongEnvironmentCatalog.chefProfileEntities(matching: "ari").isEmpty)
        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.chefProfileEntity(id: "ari")
        }
        await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.chefProfileEntity(id: "chef_ari")
        }

        let catalog = try Self.catalog(cacheSnapshot: cacheSnapshot)
        let cached = try await catalog.chefProfileEntity(id: "cached")
        #expect(cached.profileID == "chef_cached")
        #expect(cached.subtitle == "Joined Spoonjoy")
        #expect(cached.route == .profile(identifier: "cached"))
        #expect(cached.transferValue.debugFields.isEmpty)
        #expect(try await catalog.chefProfileEntities(for: ["chef_empty"]).isEmpty)

        for unsafe in ["", ".", "..", "ari\\bad", "ari..bad", " ari\nbad "] {
            await chefProfileExpectAsyncThrows(ChefProfileEntityCatalogError.self) {
                _ = try await catalog.chefProfileEntity(id: unsafe)
            }
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("chef-profile-entity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let syncStore = try FileBackedNativeSyncStore(
            fileURL: directory.appendingPathComponent("native-sync-store.json"),
            fallback: try Self.syncSnapshot(records: [
                Self.profileRecord(id: "chef_file_sync", username: "filesync")
            ])
        )
        let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("native-durable-cache.json"))
        try cacheStore.save(try Self.cacheSnapshot(records: [
            Self.profileCacheRecord(id: "chef_file_cache", username: "filecache")
        ]))

        let loaded = try await ChefProfileEntityCatalog.loading(
            syncStore: syncStore,
            cacheStore: cacheStore,
            currentAccountID: "account_ari",
            environment: .production
        )

        #expect(try await loaded.chefProfileEntity(id: "filesync").profileID == "chef_file_sync")
        #expect(try await loaded.chefProfileEntity(id: "filecache").profileID == "chef_file_cache")

        let signedOutDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("chef-profile-entity-signed-out-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: signedOutDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: signedOutDirectory) }
        let signedOutSyncStore = try FileBackedNativeSyncStore(
            fileURL: signedOutDirectory.appendingPathComponent("native-sync-store.json"),
            fallback: NativeSyncSnapshot.empty
        )
        let signedOutCacheStore = NativeDurableCacheStore(fileURL: signedOutDirectory.appendingPathComponent("native-durable-cache.json"))
        let signedOutCatalog = try await ChefProfileEntityCatalog.loading(
            syncStore: signedOutSyncStore,
            cacheStore: signedOutCacheStore,
            currentAccountID: nil,
            environment: .production
        )
        #expect(try await signedOutCatalog.suggestedChefProfileEntities(limit: 10).isEmpty)
    }

    @Test("chef profile descriptor placeholder and unresolved intent error are user safe")
    func chefProfileDescriptorPlaceholderAndUnresolvedIntentErrorAreUserSafe() {
        let placeholder = ChefProfileEntityDescriptor.placeholder
        #expect(placeholder.isPlaceholder)
        #expect(placeholder.route == .profile(identifier: "Spoonjoy"))
        #expect(placeholder.transferValue.debugFields.isEmpty)
        #expect(NativeIntentActionError.unresolvedChefProfileEntity.description == "Choose a Spoonjoy chef profile before running this Siri action.")
    }

    @Test("chef profile entity purge plans dedupe and reject wrong scopes")
    func chefProfileEntityPurgePlansDedupeAndRejectWrongScopes() {
        let scope = SpotlightIndexScope(accountID: "account_ari", environment: .production)
        let accountPlan = ChefProfileEntityIndexPurgePlan.accountScopePurge(
            accountID: "account_ari",
            environment: .production,
            profileIDs: ["chef_ari", "chef_jules", "chef_ari"]
        )

        #expect(accountPlan.identifiers == [
            SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_ari", scope: scope),
            SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_jules", scope: scope)
        ])
        #expect(accountPlan.domainIdentifiers == [
            SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope)
        ])
        #expect(accountPlan.reason == .accountScopeChanged)

        let cacheDeletePlan = ChefProfileEntityIndexPurgePlan.cacheDeletePurge(
            accountID: "account_ari",
            environment: .production,
            profileIDs: ["chef_ari", "chef_ari"]
        )
        #expect(cacheDeletePlan.identifiers == [
            SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_ari", scope: scope)
        ])
        #expect(cacheDeletePlan.domainIdentifiers.isEmpty)
        #expect(cacheDeletePlan.reason == .cacheDeleted)

        let tombstonePlan = ChefProfileEntityIndexPurgePlan.tombstonePurge(
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .recipe,
                    resourceID: "recipe_not_profile",
                    parentResourceID: nil,
                    title: "Not a profile",
                    deletedAt: "2026-06-29T01:00:00.000Z",
                    updatedAt: "2026-06-29T01:00:00.000Z"
                ),
                NativeSyncTombstone(
                    resourceType: .profile,
                    resourceID: "chef_ari",
                    parentResourceID: nil,
                    title: "ari",
                    deletedAt: "2026-06-29T01:00:00.000Z",
                    updatedAt: "2026-06-29T01:00:00.000Z"
                )
            ],
            accountID: "account_ari",
            environment: .production
        )
        #expect(tombstonePlan.identifiers == [
            SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_ari", scope: scope)
        ])
        #expect(tombstonePlan.domainIdentifiers.isEmpty)
        #expect(tombstonePlan.reason == .tombstoneApplied)

        let wrongScopePlan = ChefProfileEntityIndexPurgePlan(
            identifiers: [
                SpotlightIndexPlan.chefProfileUniqueIdentifier(
                    profileID: "chef_ari",
                    scope: SpotlightIndexScope(accountID: "account_other", environment: .production)
                )
            ],
            domainIdentifiers: [
                SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope),
                "app.spoonjoy.production.account_other.chef-profile"
            ],
            reason: .cacheDeleted
        )

        #expect(ChefProfileEntityCatalog.purgeEntityIdentifiers(
            accountID: "account_ari",
            environment: .production,
            plan: wrongScopePlan
        ).isEmpty)
        #expect(ChefProfileEntityCatalog.purgeDomainIdentifiers(
            accountID: "account_ari",
            environment: .production,
            plan: wrongScopePlan
        ) == [SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope)])
    }

    private static func catalog(
        syncSnapshot: NativeSyncSnapshot? = nil,
        cacheSnapshot: NativeDurableCacheSnapshot? = nil,
        currentAccountID: String = "account_ari",
        environment: NativeCacheEnvironment = .production
    ) throws -> ChefProfileEntityCatalog {
        try ChefProfileEntityCatalog(
            syncSnapshot: syncSnapshot ?? Self.syncSnapshot(),
            cacheSnapshot: cacheSnapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    private static func syncSnapshot(
        records: [NativeSyncCachedRecord]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> NativeSyncSnapshot {
        let ari = Self.chef(id: "chef_ari", username: "ari")
        let jules = Self.chef(id: "chef_jules", username: "jules")
        let mika = Self.chef(id: "chef_mika", username: "mika")
        let julesSoup = try Self.recipe(
            id: "recipe_jules_soup",
            title: "Jules Soup",
            chef: jules,
            recentSpoons: [
                Self.spoon(id: "spoon_ari_jules", recipeID: "recipe_jules_soup", chef: ari)
            ]
        )
        let ariBread = try Self.recipe(
            id: "recipe_ari_bread",
            title: "Ari Bread",
            chef: ari,
            recentSpoons: [
                Self.spoon(id: "spoon_mika_ari", recipeID: "recipe_ari_bread", chef: mika)
            ]
        )

        let defaultRecords = try [
            Self.profileRecord(
                id: "chef_ari",
                username: "ari",
                joinedLabel: "Joined Jun 2026",
                photoURL: URL(string: "https://spoonjoy.app/photos/profiles/chef_ari/avatar.jpg"),
                fellowChefsCount: 1,
                kitchenVisitorsCount: 1
            ),
            Self.profileRecord(id: "chef_jules", username: "jules"),
            Self.recipeRecord(julesSoup),
            Self.recipeRecord(ariBread)
        ]

        return NativeSyncSnapshot(
            accountID: "account_ari",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "chef-profile-entity-cursor"),
                shoppingCursor: nil,
                updatedAt: "2026-06-29T00:00:00.000Z"
            ),
            queue: NativeMutationQueue(),
            cachedRecords: records ?? defaultRecords,
            tombstones: tombstones
        )
    }

    private static func profileRecord(
        id: String,
        username: String,
        joinedLabel: String = "Joined Spoonjoy",
        photoURL: URL? = nil,
        fellowChefsCount: Int = 0,
        kitchenVisitorsCount: Int = 0
    ) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .profile,
            resourceID: id,
            payload: try Self.jsonValue(Self.profileSurfaceData(
                id: id,
                username: username,
                joinedLabel: joinedLabel,
                photoURL: photoURL,
                fellowChefsCount: fellowChefsCount,
                kitchenVisitorsCount: kitchenVisitorsCount
            )),
            serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
        )
    }

    private static func profileResultRecord(
        id: String,
        username: String,
        joinedLabel: String,
        photoURL: URL?,
        fellowChefsCount: Int,
        kitchenVisitorsCount: Int
    ) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .profile,
            resourceID: id,
            payload: try Self.jsonValue(ProfileSurfaceResult(
                data: Self.profileSurfaceData(
                    id: id,
                    username: username,
                    joinedLabel: joinedLabel,
                    photoURL: photoURL,
                    fellowChefsCount: fellowChefsCount,
                    kitchenVisitorsCount: kitchenVisitorsCount
                ),
                source: .live(requestID: "req_\(id)", validatedAt: Self.instant("2026-06-29T00:00:00.000Z"))
            )),
            serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
        )
    }

    private static func profileSummaryRecord(id: String, username: String) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .profile,
            resourceID: id,
            payload: try Self.jsonValue(ProfileSummary(
                id: id,
                username: username,
                photoURL: nil,
                joinedLabel: "Joined Summary",
                href: "/users/\(AppRoute.encodedProfileIdentifier(username))",
                canonicalURL: URL(string: "https://spoonjoy.app/users/\(AppRoute.encodedProfileIdentifier(username))")!
            )),
            serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
        )
    }

    private static func rawProfileRecord(
        id: String,
        username: String,
        joinedLabel: String? = nil,
        photoURLRaw: String? = nil
    ) -> NativeSyncCachedRecord {
        var fields: [String: JSONValue] = ["username": .string(username)]
        if let joinedLabel {
            fields["joinedLabel"] = .string(joinedLabel)
        }
        if let photoURLRaw {
            fields["photoUrl"] = .string(photoURLRaw)
        }
        return NativeSyncCachedRecord(
            kind: .profile,
            resourceID: id,
            payload: .object(fields),
            serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
        )
    }

    private static func profileGraphRecord(
        id: String,
        direction: ProfileGraphDirection,
        rows: [ProfileGraphRow]
    ) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .profile,
            resourceID: id,
            payload: try Self.jsonValue(ProfileGraphPage(
                profile: ProfileGraphProfile(
                    id: "chef_ari",
                    username: "ari",
                    href: "/users/ari",
                    canonicalURL: URL(string: "https://spoonjoy.app/users/ari")!
                ),
                direction: direction,
                page: 1,
                pageSize: rows.count,
                total: rows.count,
                nextCursor: nil,
                rows: rows,
                source: .cache(serverRevision: nil, lastValidatedAt: Self.instant("2026-06-29T00:00:00.000Z"))
            )),
            serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
        )
    }

    private static func recipeRecord(_ recipe: Recipe) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: recipe.id,
            payload: try Self.jsonValue(recipe),
            serverRevision: .updatedAt(recipe.updatedAt)
        )
    }

    private static func graphRow(
        chefID: String,
        username: String,
        spoons: Int,
        forks: Int,
        cookbookSaves: Int,
        latestInteractionAt: String?
    ) -> ProfileGraphRow {
        ProfileGraphRow(
            chefID: chefID,
            username: username,
            photoURL: URL(string: "https://spoonjoy.app/photos/profiles/\(chefID)/avatar.jpg"),
            href: "/users/\(AppRoute.encodedProfileIdentifier(username))",
            canonicalURL: URL(string: "https://spoonjoy.app/users/\(AppRoute.encodedProfileIdentifier(username))")!,
            interactionCounts: ProfileGraphInteractionCounts(
                spoons: spoons,
                forks: forks,
                cookbookSaves: cookbookSaves
            ),
            latestInteractionAt: latestInteractionAt
        )
    }

    private static func profileSurfaceData(
        id: String,
        username: String,
        joinedLabel: String,
        photoURL: URL?,
        fellowChefsCount: Int,
        kitchenVisitorsCount: Int
    ) -> ProfileSurfaceData {
        ProfileSurfaceData(
            profile: ProfileSummary(
                id: id,
                username: username,
                photoURL: photoURL,
                joinedLabel: joinedLabel,
                href: "/users/\(AppRoute.encodedProfileIdentifier(username))",
                canonicalURL: URL(string: "https://spoonjoy.app/users/\(AppRoute.encodedProfileIdentifier(username))")!
            ),
            isOwner: id == "chef_ari",
            recipes: [],
            cookbooks: [],
            recentSpoons: [],
            fellowChefsCount: fellowChefsCount,
            kitchenVisitorsCount: kitchenVisitorsCount
        )
    }

    private static func cacheSnapshot(records: [NativeCacheRecord]) throws -> NativeDurableCacheSnapshot {
        try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "account_ari",
            environment: .production,
            createdAt: Self.instant("2026-06-29T00:00:00.000Z"),
            records: records,
            dismissedIndicators: []
        )
    }

    private static func profileCacheRecord(id: String, username: String) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: NativeCacheDomain.profile(id: id).stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "account_ari",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: .profile(id: id),
                fetchedAt: Self.instant("2026-06-29T00:00:00.000Z"),
                lastValidatedAt: Self.instant("2026-06-29T00:00:00.000Z"),
                sourceEndpoint: "/api/v1/users/\(username)",
                serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
            ),
            payload: .profile(id: id, username: username)
        )
    }

    private static func emptyProfileCacheRecord(id: String) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: NativeCacheDomain.profile(id: id).stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "account_ari",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: .profile(id: id),
                fetchedAt: Self.instant("2026-06-29T00:00:00.000Z"),
                lastValidatedAt: Self.instant("2026-06-29T00:00:00.000Z"),
                sourceEndpoint: "/api/v1/users/\(id)",
                serverRevision: .updatedAt("2026-06-29T00:00:00.000Z")
            ),
            payload: .empty
        )
    }

    private static func recipe(
        id: String,
        title: String,
        chef: ChefSummary,
        recentSpoons: [RecipeDetailRecentSpoon]
    ) throws -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: nil,
            servings: nil,
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/\(id)")!,
            attribution: RecipeAttribution(
                creditText: "Spoonjoy",
                canonicalURL: URL(string: "https://spoonjoy.app/recipes/\(id)")!,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-06-29T00:00:00.000Z",
            updatedAt: "2026-06-29T00:00:00.000Z",
            steps: [],
            cookbooks: [],
            recentSpoons: recentSpoons
        )
    }

    private static func spoon(
        id: String,
        recipeID: String,
        chef: ChefSummary,
        cookedAt: String? = "2026-06-29T00:00:00.000Z",
        updatedAt: String = "2026-06-29T00:00:00.000Z",
        deletedAt: String? = nil
    ) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: id,
            chefID: chef.id,
            recipeID: recipeID,
            cookedAt: cookedAt,
            photoURL: nil,
            note: nil,
            nextTime: nil,
            deletedAt: deletedAt,
            createdAt: "2026-06-29T00:00:00.000Z",
            updatedAt: updatedAt,
            chef: chef
        )
    }

    private static func chef(id: String, username: String) -> ChefSummary {
        ChefSummary(
            id: id,
            username: username,
            photoURL: URL(string: "https://spoonjoy.app/photos/profiles/\(id)/avatar.jpg")
        )
    }

    private static func jsonValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    private static func instant(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}

private func chefProfileSourceContractFailures(
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
        let uncommented = chefProfileUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }

    return failures
}

private func chefProfileUncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}

private func chefProfileExpectAsyncThrows<E: Error>(
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
