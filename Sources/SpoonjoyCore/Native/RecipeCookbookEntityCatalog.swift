import Foundation

private func uniquePreservingOrder(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}

public enum RecipeCookbookEntityKind: String, Codable, Equatable, Sendable {
    case recipe
    case cookbook
}

public enum RecipeCookbookEntityCatalogError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case unavailableForScope(accountID: String?, environment: NativeCacheEnvironment?)
    case recipeNotFound(String)
    case cookbookNotFound(String)
    case undecodableRecord(kind: NativeSyncEntryKind, resourceID: String)
}

public struct RecipeCookbookEntityScope: Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }
}

public struct RecipeCookbookEntityIndexPurgePlan: Equatable, Sendable {
    public enum Reason: String, Codable, Equatable, Sendable {
        case accountScopeChanged
        case cacheDeleted
        case tombstoneApplied
    }

    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let reason: Reason

    public init(identifiers: [String], domainIdentifiers: [String], reason: Reason) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.reason = reason
    }

    public static func accountScopePurge(
        accountID: String,
        environment: NativeCacheEnvironment,
        recipeIDs: [String],
        cookbookIDs: [String]
    ) -> RecipeCookbookEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            recipeIDs: recipeIDs,
            cookbookIDs: cookbookIDs,
            includeDomain: true,
            reason: .accountScopeChanged
        )
    }

    public static func cacheDeletePurge(
        accountID: String,
        environment: NativeCacheEnvironment,
        recipeIDs: [String],
        cookbookIDs: [String]
    ) -> RecipeCookbookEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            recipeIDs: recipeIDs,
            cookbookIDs: cookbookIDs,
            includeDomain: false,
            reason: .cacheDeleted
        )
    }

    public static func tombstonePurge(
        tombstones: [NativeSyncTombstone],
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> RecipeCookbookEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            recipeIDs: tombstones.compactMap { $0.resourceType == .recipe ? $0.resourceID : nil },
            cookbookIDs: tombstones.compactMap { $0.resourceType == .cookbook ? $0.resourceID : nil },
            includeDomain: false,
            reason: .tombstoneApplied
        )
    }

    private static func scopedPlan(
        accountID: String,
        environment: NativeCacheEnvironment,
        recipeIDs: [String],
        cookbookIDs: [String],
        includeDomain: Bool,
        reason: Reason
    ) -> RecipeCookbookEntityIndexPurgePlan {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let identifiers = recipeIDs.map { SpotlightIndexPlan.recipeUniqueIdentifier(recipeID: $0, scope: spotlightScope) } +
            cookbookIDs.map { SpotlightIndexPlan.cookbookUniqueIdentifier(cookbookID: $0, scope: spotlightScope) }
        let domainIdentifiers = includeDomain
            ? [
                SpotlightIndexPlan.recipeDomainIdentifier(scope: spotlightScope),
                SpotlightIndexPlan.cookbookDomainIdentifier(scope: spotlightScope)
            ]
            : []
        return RecipeCookbookEntityIndexPurgePlan(
            identifiers: uniquePreservingOrder(identifiers),
            domainIdentifiers: uniquePreservingOrder(domainIdentifiers),
            reason: reason
        )
    }
}

public struct RecipeCookbookEntityTransferValue: Codable, Equatable, Sendable {
    public let kind: RecipeCookbookEntityKind
    public let id: String
    public let title: String
    public let chefUsername: String
    public let routeIdentifier: String
    public let canonicalURL: URL
    public let imageURL: URL?
    public let userVisibleSummary: String
    public let debugFields: [String]

    public init(
        kind: RecipeCookbookEntityKind,
        id: String,
        title: String,
        chefUsername: String,
        routeIdentifier: String,
        canonicalURL: URL,
        imageURL: URL?,
        userVisibleSummary: String,
        debugFields: [String] = []
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.chefUsername = chefUsername
        self.routeIdentifier = routeIdentifier
        self.canonicalURL = canonicalURL
        self.imageURL = imageURL
        self.userVisibleSummary = userVisibleSummary
        self.debugFields = debugFields
    }
}

public struct RecipeEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let entityIdentifier: String
    public let title: String
    public let chefID: String
    public let chefUsername: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let canonicalURL: URL
    public let imageURL: URL?
    public let transferValue: RecipeCookbookEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = RecipeEntityDescriptor(
        id: "recipe-placeholder",
        entityIdentifier: "recipe-placeholder",
        title: "Recipe",
        chefID: "chef-placeholder",
        chefUsername: "Spoonjoy",
        subtitle: "Spoonjoy recipe",
        disambiguationLabel: "Spoonjoy recipe",
        route: .recipeDetail(id: "recipe-placeholder", presentation: .detail),
        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe-placeholder")!,
        imageURL: nil,
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .recipe,
            id: "recipe-placeholder",
            title: "Recipe",
            chefUsername: "Spoonjoy",
            routeIdentifier: AppRoute.recipeDetail(id: "recipe-placeholder", presentation: .detail).stateIdentifier,
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe-placeholder")!,
            imageURL: nil,
            userVisibleSummary: "Spoonjoy recipe"
        )
    )

    public init(recipe: Recipe, scope: RecipeCookbookEntityScope? = nil) throws {
        let route = AppRoute.recipeDetail(id: recipe.id, presentation: .detail)
        _ = try NativeSharePayload.publicRecipe(recipe)
        self.init(
            id: recipe.id,
            entityIdentifier: scope.map {
                RecipeCookbookEntityCatalog.recipeEntityIdentifier(
                    recipeID: recipe.id,
                    accountID: $0.accountID,
                    environment: $0.environment
                )
            } ?? recipe.id,
            title: recipe.title,
            chefID: recipe.chef.id,
            chefUsername: recipe.chef.username,
            subtitle: Self.recipeSubtitle(chefUsername: recipe.chef.username, servings: recipe.servings),
            disambiguationLabel: "\(recipe.title) by \(recipe.chef.username)",
            route: route,
            canonicalURL: recipe.canonicalURL,
            imageURL: recipe.coverImageURL,
            transferValue: RecipeCookbookEntityTransferValue(
                kind: .recipe,
                id: recipe.id,
                title: recipe.title,
                chefUsername: recipe.chef.username,
                routeIdentifier: route.stateIdentifier,
                canonicalURL: recipe.canonicalURL,
                imageURL: recipe.coverImageURL,
                userVisibleSummary: "\(recipe.title) by \(recipe.chef.username)"
            )
        )
        _ = NativeSharePayload.publicRoute(route)
    }

    public init(
        id: String,
        entityIdentifier: String? = nil,
        title: String,
        chefID: String,
        chefUsername: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        canonicalURL: URL,
        imageURL: URL?,
        transferValue: RecipeCookbookEntityTransferValue
    ) {
        self.id = id
        self.entityIdentifier = entityIdentifier ?? id
        self.title = title
        self.chefID = chefID
        self.chefUsername = chefUsername
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.canonicalURL = canonicalURL
        self.imageURL = imageURL
        self.transferValue = transferValue
    }

    private static func recipeSubtitle(chefUsername: String, servings: String?) -> String {
        guard let servings = servings?.trimmingCharacters(in: .whitespacesAndNewlines), !servings.isEmpty else {
            return chefUsername
        }
        return "\(chefUsername) - \(servings)"
    }
}

public struct CookbookEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let entityIdentifier: String
    public let title: String
    public let chefID: String
    public let chefUsername: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let canonicalURL: URL
    public let imageURL: URL?
    public let recipeCount: Int
    public let transferValue: RecipeCookbookEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = CookbookEntityDescriptor(
        id: "cookbook-placeholder",
        entityIdentifier: "cookbook-placeholder",
        title: "Cookbook",
        chefID: "chef-placeholder",
        chefUsername: "Spoonjoy",
        subtitle: "Spoonjoy cookbook",
        disambiguationLabel: "Spoonjoy cookbook",
        route: .cookbookDetail(id: "cookbook-placeholder"),
        canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/cookbook-placeholder")!,
        imageURL: nil,
        recipeCount: 0,
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .cookbook,
            id: "cookbook-placeholder",
            title: "Cookbook",
            chefUsername: "Spoonjoy",
            routeIdentifier: AppRoute.cookbookDetail(id: "cookbook-placeholder").stateIdentifier,
            canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/cookbook-placeholder")!,
            imageURL: nil,
            userVisibleSummary: "Spoonjoy cookbook"
        )
    )

    public init(cookbook: Cookbook, scope: RecipeCookbookEntityScope? = nil) throws {
        let route = AppRoute.cookbookDetail(id: cookbook.id)
        _ = try NativeSharePayload.publicCookbook(cookbook)
        let summary = "\(cookbook.title) by \(cookbook.chef.username)"
        self.init(
            id: cookbook.id,
            entityIdentifier: scope.map {
                RecipeCookbookEntityCatalog.cookbookEntityIdentifier(
                    cookbookID: cookbook.id,
                    accountID: $0.accountID,
                    environment: $0.environment
                )
            } ?? cookbook.id,
            title: cookbook.title,
            chefID: cookbook.chef.id,
            chefUsername: cookbook.chef.username,
            subtitle: "\(cookbook.chef.username) - \(cookbook.recipeCount) \(Self.recipeCountLabel(cookbook.recipeCount))",
            disambiguationLabel: summary,
            route: route,
            canonicalURL: cookbook.canonicalURL,
            imageURL: cookbook.cover.primaryImageURL,
            recipeCount: cookbook.recipeCount,
            transferValue: RecipeCookbookEntityTransferValue(
                kind: .cookbook,
                id: cookbook.id,
                title: cookbook.title,
                chefUsername: cookbook.chef.username,
                routeIdentifier: route.stateIdentifier,
                canonicalURL: cookbook.canonicalURL,
                imageURL: cookbook.cover.primaryImageURL,
                userVisibleSummary: summary
            )
        )
        _ = NativeSharePayload.publicRoute(route)
    }

    public init(
        id: String,
        entityIdentifier: String? = nil,
        title: String,
        chefID: String,
        chefUsername: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        canonicalURL: URL,
        imageURL: URL?,
        recipeCount: Int,
        transferValue: RecipeCookbookEntityTransferValue
    ) {
        self.id = id
        self.entityIdentifier = entityIdentifier ?? id
        self.title = title
        self.chefID = chefID
        self.chefUsername = chefUsername
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.canonicalURL = canonicalURL
        self.imageURL = imageURL
        self.recipeCount = recipeCount
        self.transferValue = transferValue
    }

    private static func recipeCountLabel(_ count: Int) -> String {
        count == 1 ? "recipe" : "recipes"
    }
}

public struct RecipeCookbookEntityCatalog: Sendable {
    private let recipes: [Recipe]
    private let cookbooks: [Cookbook]
    private let scopeAvailable: Bool
    private let scope: RecipeCookbookEntityScope?

    public init(
        syncSnapshot: NativeSyncSnapshot,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) {
        scopeAvailable = syncSnapshot.accountID == currentAccountID && syncSnapshot.environment == environment
        guard scopeAvailable else {
            scope = nil
            recipes = []
            cookbooks = []
            return
        }

        scope = currentAccountID.map { RecipeCookbookEntityScope(accountID: $0, environment: environment) }
        let tombstonedRecipes = Set(syncSnapshot.tombstones.compactMap { tombstone in
            tombstone.resourceType == .recipe ? tombstone.resourceID : nil
        })
        let tombstonedCookbooks = Set(syncSnapshot.tombstones.compactMap { tombstone in
            tombstone.resourceType == .cookbook ? tombstone.resourceID : nil
        })
        recipes = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.recipe && !tombstonedRecipes.contains($0.resourceID) }
            .compactMap { Self.decode(Recipe.self, from: $0) }
        cookbooks = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.cookbook && !tombstonedCookbooks.contains($0.resourceID) }
            .compactMap { Self.decode(Cookbook.self, from: $0) }
    }

    public static func loading(syncStore: any NativeSyncStore, currentAccountID: String?, environment: NativeCacheEnvironment) async throws -> RecipeCookbookEntityCatalog {
        let snapshot = try await syncStore.loadSnapshot()
        return RecipeCookbookEntityCatalog(
            syncSnapshot: snapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    public func recipeEntity(id: String) async throws -> RecipeEntityDescriptor {
        let scope = try ensureScopeAvailable()
        let id = try scopedRecipeIdentifier(id)
        guard let recipe = recipes.first(where: { $0.id == id }) else {
            throw RecipeCookbookEntityCatalogError.recipeNotFound(id)
        }
        return try RecipeEntityDescriptor(recipe: recipe, scope: scope)
    }

    public func cookbookEntity(id: String) async throws -> CookbookEntityDescriptor {
        let scope = try ensureScopeAvailable()
        let id = try scopedCookbookIdentifier(id)
        guard let cookbook = cookbooks.first(where: { $0.id == id }) else {
            throw RecipeCookbookEntityCatalogError.cookbookNotFound(id)
        }
        return try CookbookEntityDescriptor(cookbook: cookbook, scope: scope)
    }

    public func recipeEntities(for identifiers: [String]) async throws -> [RecipeEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        var entities: [RecipeEntityDescriptor] = []
        for identifier in identifiers {
            guard let id = try? scopedRecipeIdentifier(identifier) else {
                continue
            }
            guard let recipe = recipes.first(where: { $0.id == id }) else {
                continue
            }
            entities.append(try RecipeEntityDescriptor(recipe: recipe, scope: scope))
        }
        return entities
    }

    public func cookbookEntities(for identifiers: [String]) async throws -> [CookbookEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        var entities: [CookbookEntityDescriptor] = []
        for identifier in identifiers {
            guard let id = try? scopedCookbookIdentifier(identifier) else {
                continue
            }
            guard let cookbook = cookbooks.first(where: { $0.id == id }) else {
                continue
            }
            entities.append(try CookbookEntityDescriptor(cookbook: cookbook, scope: scope))
        }
        return entities
    }

    public func recipeEntities(matching string: String) async throws -> [RecipeEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? recipes : recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(query) ||
                recipe.chef.username.localizedCaseInsensitiveContains(query) ||
                recipe.description?.localizedCaseInsensitiveContains(query) == true ||
                recipe.servings?.localizedCaseInsensitiveContains(query) == true
        }
        return try matches.map { try RecipeEntityDescriptor(recipe: $0, scope: scope) }
    }

    public func cookbookEntities(matching string: String) async throws -> [CookbookEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? cookbooks : cookbooks.filter { cookbook in
            cookbook.title.localizedCaseInsensitiveContains(query) ||
                cookbook.chef.username.localizedCaseInsensitiveContains(query) ||
                cookbook.recipes.contains { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return try matches.map { try CookbookEntityDescriptor(cookbook: $0, scope: scope) }
    }

    public func suggestedRecipeEntities(limit: Int = 10) async throws -> [RecipeEntityDescriptor] {
        guard scopeAvailable else {
            return []
        }
        return try recipes.prefix(max(0, limit)).map { try RecipeEntityDescriptor(recipe: $0, scope: scope) }
    }

    public func suggestedCookbookEntities(limit: Int = 10) async throws -> [CookbookEntityDescriptor] {
        guard scopeAvailable else {
            return []
        }
        return try cookbooks.prefix(max(0, limit)).map { try CookbookEntityDescriptor(cookbook: $0, scope: scope) }
    }

    public static func recipeEntityIdentifier(recipeID: String, accountID: String, environment: NativeCacheEnvironment) -> String {
        "recipe:\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID):\(recipeID)"
    }

    public static func cookbookEntityIdentifier(cookbookID: String, accountID: String, environment: NativeCacheEnvironment) -> String {
        "cookbook:\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID):\(cookbookID)"
    }

    public static func resolvedRecipeID(
        from identifier: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> String {
        let parts = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 5,
              parts[0] == "recipe",
              parts[1] == environment.rawValue,
              parts[2] == "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)",
              parts[3] == accountID,
              !parts[4].isEmpty else {
            throw RecipeCookbookEntityCatalogError.invalidIdentifier(identifier)
        }
        return parts[4]
    }

    public static func resolvedCookbookID(
        from identifier: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> String {
        let parts = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 5,
              parts[0] == "cookbook",
              parts[1] == environment.rawValue,
              parts[2] == "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)",
              parts[3] == accountID,
              !parts[4].isEmpty else {
            throw RecipeCookbookEntityCatalogError.invalidIdentifier(identifier)
        }
        return parts[4]
    }

    public static func purgeEntityIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: RecipeCookbookEntityIndexPurgePlan
    ) -> [String] {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let recipePrefix = "\(spotlightScope.identifierPrefix)|\(SpotlightIndexType.recipe.rawValue)|"
        let cookbookPrefix = "\(spotlightScope.identifierPrefix)|\(SpotlightIndexType.cookbook.rawValue)|"
        guard plan.identifiers.allSatisfy({ $0.hasPrefix(recipePrefix) || $0.hasPrefix(cookbookPrefix) }) else {
            return []
        }
        return plan.identifiers
    }

    public static func purgeDomainIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: RecipeCookbookEntityIndexPurgePlan
    ) -> [String] {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let expectedDomains = Set([
            SpotlightIndexPlan.recipeDomainIdentifier(scope: spotlightScope),
            SpotlightIndexPlan.cookbookDomainIdentifier(scope: spotlightScope)
        ])
        return plan.domainIdentifiers.filter { expectedDomains.contains($0) }
    }

    private func ensureScopeAvailable() throws -> RecipeCookbookEntityScope {
        guard scopeAvailable, let scope else {
            throw RecipeCookbookEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
        return scope
    }

    private func scopedRecipeIdentifier(_ rawValue: String) throws -> String {
        let scope = try ensureScopeAvailable()
        return try Self.resolvedRecipeID(from: rawValue, accountID: scope.accountID, environment: scope.environment)
    }

    private func scopedCookbookIdentifier(_ rawValue: String) throws -> String {
        let scope = try ensureScopeAvailable()
        return try Self.resolvedCookbookID(from: rawValue, accountID: scope.accountID, environment: scope.environment)
    }

    private func normalizedQuery(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from record: NativeSyncCachedRecord) -> Value? {
        try? JSONDecoder().decode(type, from: JSONEncoder().encode(record.payload))
    }
}
