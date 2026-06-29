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
                    "NativeSyncEntryKind.profile",
                    "NativeSyncEntryKind.recipe",
                    "NativeDurableCacheSnapshot",
                    "NativeDurableCacheStore",
                    "NativeCachePayload.profile",
                    "NativeCacheDomain.profile",
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

    @Test("chef profile entities filter wrong scopes reject unsafe identifiers and load stores")
    func chefProfileEntitiesFilterWrongScopesRejectUnsafeIdentifiersAndLoadStores() async throws {
        let syncSnapshot = try Self.syncSnapshot()
        let cacheSnapshot = try Self.cacheSnapshot(records: [
            Self.profileCacheRecord(id: "chef_cached", username: "cached")
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

    private static func syncSnapshot(records: [NativeSyncCachedRecord]? = nil) throws -> NativeSyncSnapshot {
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
            tombstones: []
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

    private static func recipeRecord(_ recipe: Recipe) throws -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: recipe.id,
            payload: try Self.jsonValue(recipe),
            serverRevision: .updatedAt(recipe.updatedAt)
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

    private static func spoon(id: String, recipeID: String, chef: ChefSummary) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: id,
            chefID: chef.id,
            recipeID: recipeID,
            cookedAt: "2026-06-29T00:00:00.000Z",
            photoURL: nil,
            note: nil,
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-29T00:00:00.000Z",
            updatedAt: "2026-06-29T00:00:00.000Z",
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
