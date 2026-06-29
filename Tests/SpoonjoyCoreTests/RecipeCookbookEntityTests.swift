import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe and cookbook App Entity contracts")
struct RecipeCookbookEntityTests {
    @Test("recipe and cookbook entity sources exist with AppIntents contracts")
    func recipeAndCookbookEntitySourcesExistWithAppIntentsContracts() throws {
        let failures = sourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift": [
                    "RecipeCookbookEntityCatalog",
                    "RecipeEntityDescriptor",
                    "CookbookEntityDescriptor",
                    "RecipeCookbookEntityTransferValue",
                    "RecipeCookbookEntityKind",
                    "isPlaceholder",
                    "recipeEntity(id:",
                    "cookbookEntity(id:",
                    "recipeEntities(for identifiers:",
                    "cookbookEntities(for identifiers:",
                    "recipeEntities(matching string:",
                    "cookbookEntities(matching string:",
                    "suggestedRecipeEntities",
                    "suggestedCookbookEntities",
                    "loading(syncStore:",
                    "loadSnapshot()",
                    "NativeSyncSnapshot",
                    "NativeSyncCachedRecord",
                    "NativeSyncEntryKind.recipe",
                    "NativeSyncEntryKind.cookbook",
                    "tombstones",
                    "accountID",
                    "environment",
                    "AppRoute.recipeDetail",
                    "AppRoute.cookbookDetail",
                    "NativeSharePayload.publicRoute",
                    "canonicalURL",
                    "disambiguationLabel",
                    "transferValue",
                    "chefUsername"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import CoreTransferable",
                    "import SpoonjoyCore",
                    "@available(iOS 27.0, macOS 27.0, *)",
                    "struct SpoonjoyRecipeEntity: AppEntity",
                    "struct SpoonjoyCookbookEntity: AppEntity",
                    "struct SpoonjoyRecipeEntityQuery: EntityQuery, EntityStringQuery",
                    "struct SpoonjoyCookbookEntityQuery: EntityQuery, EntityStringQuery",
                    "typealias DefaultQuery = SpoonjoyRecipeEntityQuery",
                    "typealias DefaultQuery = SpoonjoyCookbookEntityQuery",
                    "static let typeDisplayRepresentation",
                    "var displayRepresentation",
                    "DisplayRepresentation",
                    "TypeDisplayRepresentation",
                    "entities(for identifiers: [String]) async throws",
                    "entities(matching string: String) async throws",
                    "suggestedEntities() async throws",
                    "RecipeCookbookEntityCatalog",
                    "RecipeEntityDescriptor",
                    "CookbookEntityDescriptor",
                    "Transferable",
                    "TransferRepresentation",
                    "RecipeCookbookEntityTransferValue",
                    "resolvedRecipeID() throws",
                    "NativeIntentActionError.unresolvedRecipeEntity",
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
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Recipe\", requestValueDialog:",
                    "var recipe: SpoonjoyRecipeEntity",
                    "try recipe.resolvedRecipeID()"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "SpoonjoyRecipeEntity",
                    "SpoonjoyCookbookEntity",
                    "SpoonjoyRecipeEntityQuery",
                    "SpoonjoyCookbookEntityQuery"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "recipe App Entity",
                    "cookbook App Entity",
                    "RecipeCookbookEntityCatalog",
                    "SpoonjoyRecipeEntity",
                    "SpoonjoyCookbookEntity"
                ]
            ],
            forbiddenTokens: [
                "@Parameter(title: \"Recipe ID\")",
                "@Parameter(title: \"Cookbook ID\")",
                "recipe.descriptor.id",
                "recipe-entity",
                "cookbook-entity",
                "String-only recipe App Intent",
                "TODO AppEntity",
                "eventually add entities"
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("recipe entities resolve from native sync cached records and expose transfer values")
    func recipeEntitiesResolveFromNativeSyncCachedRecordsAndExposeTransferValues() async throws {
        let catalog = try Self.entityCatalog()

        let lemon = try await catalog.recipeEntity(id: "recipe_lemon_pantry_pasta")
        #expect(lemon.id == "recipe_lemon_pantry_pasta")
        #expect(lemon.title == "Lemon Pantry Pasta")
        #expect(lemon.chefUsername == "ari")
        #expect(lemon.subtitle == "ari - 4")
        #expect(lemon.disambiguationLabel == "Lemon Pantry Pasta by ari")
        #expect(lemon.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(lemon.canonicalURL == URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta"))
        #expect(lemon.imageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))

        let transfer = lemon.transferValue
        #expect(transfer.kind == .recipe)
        #expect(transfer.id == lemon.id)
        #expect(transfer.title == lemon.title)
        #expect(transfer.chefUsername == "ari")
        #expect(transfer.routeIdentifier == "recipe:recipe_lemon_pantry_pasta")
        #expect(transfer.canonicalURL == lemon.canonicalURL)
        #expect(transfer.imageURL == lemon.imageURL)
        #expect(transfer.userVisibleSummary == "Lemon Pantry Pasta by ari")
        #expect(transfer.debugFields.isEmpty)

        let matches = try await catalog.recipeEntities(matching: "  lemon  ")
        #expect(matches.map(\.id) == ["recipe_lemon_pantry_pasta"])

        let byIdentifier = try await catalog.recipeEntities(for: ["recipe_tomato_toast", "recipe_lemon_pantry_pasta"])
        #expect(byIdentifier.map(\.id) == ["recipe_tomato_toast", "recipe_lemon_pantry_pasta"])

        let mixedStaleBatch = try await catalog.recipeEntities(for: [
            "recipe_missing_from_old_shortcut",
            "  recipe_lemon_pantry_pasta  ",
            "recipe_deleted_from_old_donation",
            "recipe_tomato_toast"
        ])
        #expect(mixedStaleBatch.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_toast"])

        let suggested = try await catalog.suggestedRecipeEntities(limit: 10)
        #expect(suggested.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_toast"])
    }

    @Test("cookbook entities resolve from native sync cached records and expose transfer values")
    func cookbookEntitiesResolveFromNativeSyncCachedRecordsAndExposeTransferValues() async throws {
        let catalog = try Self.entityCatalog()

        let weeknights = try await catalog.cookbookEntity(id: "cookbook_weeknights")
        #expect(weeknights.id == "cookbook_weeknights")
        #expect(weeknights.title == "Weeknights")
        #expect(weeknights.chefUsername == "ari")
        #expect(weeknights.subtitle == "ari - 2 recipes")
        #expect(weeknights.disambiguationLabel == "Weeknights by ari")
        #expect(weeknights.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(weeknights.canonicalURL == URL(string: "https://spoonjoy.app/cookbooks/cookbook_weeknights"))
        #expect(weeknights.imageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(weeknights.recipeCount == 2)

        let transfer = weeknights.transferValue
        #expect(transfer.kind == .cookbook)
        #expect(transfer.id == weeknights.id)
        #expect(transfer.title == weeknights.title)
        #expect(transfer.chefUsername == "ari")
        #expect(transfer.routeIdentifier == "cookbook:cookbook_weeknights")
        #expect(transfer.canonicalURL == weeknights.canonicalURL)
        #expect(transfer.imageURL == weeknights.imageURL)
        #expect(transfer.userVisibleSummary == "Weeknights by ari")
        #expect(transfer.debugFields.isEmpty)

        let matches = try await catalog.cookbookEntities(matching: "  inbox  ")
        #expect(matches.map(\.id) == ["cookbook_no_covers"])

        let byIdentifier = try await catalog.cookbookEntities(for: ["cookbook_no_covers", "cookbook_weeknights"])
        #expect(byIdentifier.map(\.id) == ["cookbook_no_covers", "cookbook_weeknights"])

        let mixedStaleBatch = try await catalog.cookbookEntities(for: [
            "cookbook_missing_from_old_shortcut",
            "  cookbook_weeknights  ",
            "cookbook_deleted_from_old_donation",
            "cookbook_no_covers"
        ])
        #expect(mixedStaleBatch.map(\.id) == ["cookbook_weeknights", "cookbook_no_covers"])

        let suggested = try await catalog.suggestedCookbookEntities(limit: 10)
        #expect(suggested.map(\.id) == ["cookbook_weeknights", "cookbook_no_covers"])
    }

    @Test("entity search disambiguates same-title recipes and cookbooks deterministically")
    func entitySearchDisambiguatesSameTitleRecipesAndCookbooksDeterministically() async throws {
        let recipeCatalog = try RecipeFixtureCatalog.decodeFromBundle()
        let cookbookCatalog = try CookbookFixtureCatalog.decodeFromBundle()
        let lemon = try #require(recipeCatalog.recipe(id: "recipe_lemon_pantry_pasta"))
        let weeknights = try #require(cookbookCatalog.cookbook(id: "cookbook_weeknights"))
        let secondChef = ChefSummary(id: "chef_bea", username: "bea")
        let beaRecipe = Self.recipeVariant(
            lemon,
            id: "recipe_lemon_pantry_pasta_bea",
            title: lemon.title,
            chef: secondChef
        )
        let beaCookbook = Self.cookbookVariant(
            weeknights,
            id: "cookbook_weeknights_bea",
            title: weeknights.title,
            chef: secondChef
        )
        let catalog = RecipeCookbookEntityCatalog(
            syncSnapshot: try Self.syncSnapshot(records: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: lemon.id,
                    payload: Self.jsonValue(lemon),
                    serverRevision: .updatedAt(lemon.updatedAt)
                ),
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: beaRecipe.id,
                    payload: Self.jsonValue(beaRecipe),
                    serverRevision: .updatedAt(beaRecipe.updatedAt)
                ),
                NativeSyncCachedRecord(
                    kind: .cookbook,
                    resourceID: weeknights.id,
                    payload: Self.jsonValue(weeknights),
                    serverRevision: .updatedAt(weeknights.updatedAt)
                ),
                NativeSyncCachedRecord(
                    kind: .cookbook,
                    resourceID: beaCookbook.id,
                    payload: Self.jsonValue(beaCookbook),
                    serverRevision: .updatedAt(beaCookbook.updatedAt)
                )
            ]),
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.production
        )

        let recipeMatches = try await catalog.recipeEntities(matching: "lemon pantry")
        #expect(recipeMatches.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_lemon_pantry_pasta_bea"])
        #expect(recipeMatches.map(\.disambiguationLabel) == [
            "Lemon Pantry Pasta by ari",
            "Lemon Pantry Pasta by bea"
        ])

        let cookbookMatches = try await catalog.cookbookEntities(matching: "weeknight")
        #expect(cookbookMatches.map(\.id) == ["cookbook_weeknights", "cookbook_weeknights_bea"])
        #expect(cookbookMatches.map(\.disambiguationLabel) == [
            "Weeknights by ari",
            "Weeknights by bea"
        ])
    }

    @Test("entity catalog loads persisted sync store snapshots")
    func entityCatalogLoadsPersistedSyncStoreSnapshots() async throws {
        let snapshot = try Self.syncSnapshot()
        let store = InMemoryNativeSyncStore(
            accountID: snapshot.accountID,
            environment: snapshot.environment,
            checkpoint: snapshot.checkpoint,
            queue: snapshot.queue,
            cachedRecords: snapshot.cachedRecords
        )
        let catalog = try await RecipeCookbookEntityCatalog.loading(
            syncStore: store,
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.production
        )

        #expect(try await catalog.recipeEntity(id: "recipe_lemon_pantry_pasta").title == "Lemon Pantry Pasta")
        #expect(try await catalog.cookbookEntity(id: "cookbook_weeknights").title == "Weeknights")
    }

    @Test("entity descriptors cover placeholder sparse recipe and singular cookbook display edges")
    func entityDescriptorsCoverPlaceholderSparseRecipeAndSingularCookbookDisplayEdges() async throws {
        let recipeCatalog = try RecipeFixtureCatalog.decodeFromBundle()
        let cookbookCatalog = try CookbookFixtureCatalog.decodeFromBundle()
        let lemon = try #require(recipeCatalog.recipe(id: "recipe_lemon_pantry_pasta"))
        let weeknights = try #require(cookbookCatalog.cookbook(id: "cookbook_weeknights"))
        let sparseRecipe = Self.recipeVariant(
            lemon,
            id: "recipe_plain_toast",
            title: "Plain Toast",
            chef: lemon.chef,
            servings: "   "
        )
        let singularCookbook = Self.cookbookVariant(
            weeknights,
            id: "cookbook_one_recipe",
            title: "Solo Suppers",
            chef: weeknights.chef,
            recipeCount: 1,
            recipes: Array(weeknights.recipes.prefix(1))
        )
        let catalog = RecipeCookbookEntityCatalog(
            syncSnapshot: try Self.syncSnapshot(records: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: sparseRecipe.id,
                    payload: Self.jsonValue(sparseRecipe),
                    serverRevision: .updatedAt(sparseRecipe.updatedAt)
                ),
                NativeSyncCachedRecord(
                    kind: .cookbook,
                    resourceID: singularCookbook.id,
                    payload: Self.jsonValue(singularCookbook),
                    serverRevision: .updatedAt(singularCookbook.updatedAt)
                )
            ]),
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.production
        )

        #expect(RecipeEntityDescriptor.placeholder.isPlaceholder)
        #expect(CookbookEntityDescriptor.placeholder.isPlaceholder)

        let recipe = try await catalog.recipeEntity(id: "recipe_plain_toast")
        #expect(!recipe.isPlaceholder)
        #expect(recipe.subtitle == "ari")
        #expect(recipe.canonicalURL == sparseRecipe.canonicalURL)
        #expect(recipe.transferValue.canonicalURL == sparseRecipe.canonicalURL)

        let cookbook = try await catalog.cookbookEntity(id: "cookbook_one_recipe")
        #expect(!cookbook.isPlaceholder)
        #expect(cookbook.subtitle == "ari - 1 recipe")
        #expect(cookbook.recipeCount == 1)
        #expect(cookbook.canonicalURL == singularCookbook.canonicalURL)
        #expect(cookbook.transferValue.canonicalURL == singularCookbook.canonicalURL)

        let allRecipes = try await catalog.recipeEntities(matching: "   ")
        #expect(allRecipes.map(\.id) == ["recipe_plain_toast"])

        let allCookbooks = try await catalog.cookbookEntities(matching: "")
        #expect(allCookbooks.map(\.id) == ["cookbook_one_recipe"])
    }

    @Test("entity catalog trims identifiers and reports missing cached entities")
    func entityCatalogTrimsIdentifiersAndReportsMissingCachedEntities() async throws {
        let catalog = try Self.entityCatalog()

        let tomato = try await catalog.recipeEntity(id: "  recipe_tomato_toast  ")
        #expect(tomato.id == "recipe_tomato_toast")

        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.recipeEntity(id: "")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.cookbookEntity(id: "../cookbook_weeknights")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.recipeEntity(id: "recipe_missing")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.cookbookEntity(id: "cookbook_missing")
        }
    }

    @Test("entity catalog honors sync account environment and tombstone boundaries")
    func entityCatalogHonorsSyncAccountEnvironmentAndTombstoneBoundaries() async throws {
        let recipeCatalog = try RecipeFixtureCatalog.decodeFromBundle()
        let cookbookCatalog = try CookbookFixtureCatalog.decodeFromBundle()
        let recipe = try #require(recipeCatalog.recipe(id: "recipe_tomato_toast"))
        let cookbook = try #require(cookbookCatalog.cookbook(id: "cookbook_no_covers"))
        let snapshot = try Self.syncSnapshot(
            records: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: recipe.id,
                    payload: Self.jsonValue(recipe),
                    serverRevision: .updatedAt(recipe.updatedAt)
                ),
                NativeSyncCachedRecord(
                    kind: .cookbook,
                    resourceID: cookbook.id,
                    payload: Self.jsonValue(cookbook),
                    serverRevision: .updatedAt(cookbook.updatedAt)
                )
            ],
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .recipe,
                    resourceID: recipe.id,
                    parentResourceID: nil,
                    title: recipe.title,
                    deletedAt: "2026-06-29T00:00:00.000Z",
                    updatedAt: "2026-06-29T00:00:00.000Z"
                ),
                NativeSyncTombstone(
                    resourceType: .cookbook,
                    resourceID: cookbook.id,
                    parentResourceID: nil,
                    title: cookbook.title,
                    deletedAt: "2026-06-29T00:00:00.000Z",
                    updatedAt: "2026-06-29T00:00:00.000Z"
                )
            ]
        )
        let catalog = RecipeCookbookEntityCatalog(
            syncSnapshot: snapshot,
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.production
        )

        #expect(try await catalog.suggestedRecipeEntities(limit: 10).isEmpty)
        #expect(try await catalog.suggestedCookbookEntities(limit: 10).isEmpty)
        #expect(try await catalog.recipeEntities(for: [recipe.id]).isEmpty)
        #expect(try await catalog.cookbookEntities(for: [cookbook.id]).isEmpty)
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.recipeEntity(id: recipe.id)
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await catalog.cookbookEntity(id: cookbook.id)
        }

        let wrongAccountCatalog = RecipeCookbookEntityCatalog(
            syncSnapshot: try Self.syncSnapshot(),
            currentAccountID: "account_other",
            environment: NativeCacheEnvironment.production
        )
        let wrongEnvironmentCatalog = RecipeCookbookEntityCatalog(
            syncSnapshot: try Self.syncSnapshot(),
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.local
        )

        #expect(try await wrongAccountCatalog.suggestedRecipeEntities(limit: 10).isEmpty)
        #expect(try await wrongEnvironmentCatalog.suggestedCookbookEntities(limit: 10).isEmpty)
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.recipeEntity(id: "recipe_lemon_pantry_pasta")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.cookbookEntity(id: "cookbook_weeknights")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.recipeEntity(id: "recipe_lemon_pantry_pasta")
        }
        await expectAsyncThrows(RecipeCookbookEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.cookbookEntity(id: "cookbook_weeknights")
        }
    }

    private static func entityCatalog() throws -> RecipeCookbookEntityCatalog {
        RecipeCookbookEntityCatalog(
            syncSnapshot: try syncSnapshot(),
            currentAccountID: "account_ari",
            environment: NativeCacheEnvironment.production
        )
    }

    private static func syncSnapshot(
        records: [NativeSyncCachedRecord]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> NativeSyncSnapshot {
        let recipeCatalog = try RecipeFixtureCatalog.decodeFromBundle()
        let cookbookCatalog = try CookbookFixtureCatalog.decodeFromBundle()
        let recipeRecords = try recipeCatalog.recipes.map {
            NativeSyncCachedRecord(
                kind: .recipe,
                resourceID: $0.id,
                payload: try jsonValue($0),
                serverRevision: .updatedAt($0.updatedAt)
            )
        }
        let cookbookRecords = try cookbookCatalog.cookbooks.map {
            NativeSyncCachedRecord(
                kind: .cookbook,
                resourceID: $0.id,
                payload: try jsonValue($0),
                serverRevision: .updatedAt($0.updatedAt)
            )
        }

        return NativeSyncSnapshot(
            accountID: "account_ari",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "entity-cursor"),
                shoppingCursor: nil,
                updatedAt: "2026-06-29T00:00:00.000Z"
            ),
            queue: NativeMutationQueue(),
            cachedRecords: records ?? recipeRecords + cookbookRecords,
            tombstones: tombstones
        )
    }

    private static func jsonValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    private static func recipeVariant(
        _ recipe: Recipe,
        id: String,
        title: String,
        chef: ChefSummary,
        servings: String? = nil
    ) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: recipe.description,
            servings: servings ?? recipe.servings,
            chef: chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/\(id)",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/\(id)")!,
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            steps: recipe.steps,
            cookbooks: recipe.cookbooks,
            recentSpoons: recipe.recentSpoons
        )
    }

    private static func cookbookVariant(
        _ cookbook: Cookbook,
        id: String,
        title: String,
        chef: ChefSummary,
        recipeCount: Int? = nil,
        recipes: [RecipeSummary]? = nil
    ) -> Cookbook {
        Cookbook(
            id: id,
            title: title,
            chef: chef,
            recipeCount: recipeCount ?? cookbook.recipeCount,
            cover: cookbook.cover,
            href: "/cookbooks/\(id)",
            canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/\(id)")!,
            attribution: cookbook.attribution,
            createdAt: cookbook.createdAt,
            updatedAt: cookbook.updatedAt,
            recipes: recipes ?? cookbook.recipes
        )
    }
}

private func sourceContractFailures(
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
        let uncommented = uncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }

    return failures
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}

private func expectAsyncThrows<E: Error>(
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
