import Foundation

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
    public let title: String
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
        title: "Recipe",
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

    public init(recipe: Recipe) throws {
        let route = AppRoute.recipeDetail(id: recipe.id, presentation: .detail)
        _ = try NativeSharePayload.publicRecipe(recipe)
        self.init(
            id: recipe.id,
            title: recipe.title,
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
        title: String,
        chefUsername: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        canonicalURL: URL,
        imageURL: URL?,
        transferValue: RecipeCookbookEntityTransferValue
    ) {
        self.id = id
        self.title = title
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
    public let title: String
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
        title: "Cookbook",
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

    public init(cookbook: Cookbook) throws {
        let route = AppRoute.cookbookDetail(id: cookbook.id)
        _ = try NativeSharePayload.publicCookbook(cookbook)
        let summary = "\(cookbook.title) by \(cookbook.chef.username)"
        self.init(
            id: cookbook.id,
            title: cookbook.title,
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
        title: String,
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
        self.title = title
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

    public init(
        syncSnapshot: NativeSyncSnapshot,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) {
        scopeAvailable = syncSnapshot.accountID == currentAccountID && syncSnapshot.environment == environment
        guard scopeAvailable else {
            recipes = []
            cookbooks = []
            return
        }

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
        try ensureScopeAvailable()
        let id = try canonicalIdentifier(id)
        guard let recipe = recipes.first(where: { $0.id == id }) else {
            throw RecipeCookbookEntityCatalogError.recipeNotFound(id)
        }
        return try RecipeEntityDescriptor(recipe: recipe)
    }

    public func cookbookEntity(id: String) async throws -> CookbookEntityDescriptor {
        try ensureScopeAvailable()
        let id = try canonicalIdentifier(id)
        guard let cookbook = cookbooks.first(where: { $0.id == id }) else {
            throw RecipeCookbookEntityCatalogError.cookbookNotFound(id)
        }
        return try CookbookEntityDescriptor(cookbook: cookbook)
    }

    public func recipeEntities(for identifiers: [String]) async throws -> [RecipeEntityDescriptor] {
        try ensureScopeAvailable()
        var entities: [RecipeEntityDescriptor] = []
        for identifier in identifiers {
            let id = try canonicalIdentifier(identifier)
            guard let recipe = recipes.first(where: { $0.id == id }) else {
                continue
            }
            entities.append(try RecipeEntityDescriptor(recipe: recipe))
        }
        return entities
    }

    public func cookbookEntities(for identifiers: [String]) async throws -> [CookbookEntityDescriptor] {
        try ensureScopeAvailable()
        var entities: [CookbookEntityDescriptor] = []
        for identifier in identifiers {
            let id = try canonicalIdentifier(identifier)
            guard let cookbook = cookbooks.first(where: { $0.id == id }) else {
                continue
            }
            entities.append(try CookbookEntityDescriptor(cookbook: cookbook))
        }
        return entities
    }

    public func recipeEntities(matching string: String) async throws -> [RecipeEntityDescriptor] {
        try ensureScopeAvailable()
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? recipes : recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(query) ||
                recipe.chef.username.localizedCaseInsensitiveContains(query) ||
                recipe.description?.localizedCaseInsensitiveContains(query) == true ||
                recipe.servings?.localizedCaseInsensitiveContains(query) == true
        }
        return try matches.map(RecipeEntityDescriptor.init)
    }

    public func cookbookEntities(matching string: String) async throws -> [CookbookEntityDescriptor] {
        try ensureScopeAvailable()
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? cookbooks : cookbooks.filter { cookbook in
            cookbook.title.localizedCaseInsensitiveContains(query) ||
                cookbook.chef.username.localizedCaseInsensitiveContains(query) ||
                cookbook.recipes.contains { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return try matches.map(CookbookEntityDescriptor.init)
    }

    public func suggestedRecipeEntities(limit: Int = 10) async throws -> [RecipeEntityDescriptor] {
        guard scopeAvailable else {
            return []
        }
        return try recipes.prefix(max(0, limit)).map(RecipeEntityDescriptor.init)
    }

    public func suggestedCookbookEntities(limit: Int = 10) async throws -> [CookbookEntityDescriptor] {
        guard scopeAvailable else {
            return []
        }
        return try cookbooks.prefix(max(0, limit)).map(CookbookEntityDescriptor.init)
    }

    private func ensureScopeAvailable() throws {
        guard scopeAvailable else {
            throw RecipeCookbookEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
    }

    private func canonicalIdentifier(_ rawValue: String) throws -> String {
        let id = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !id.isEmpty,
            !id.contains("/"),
            !id.contains("\\"),
            !id.contains(".."),
            id != ".",
            id != "..",
            id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        else {
            throw RecipeCookbookEntityCatalogError.invalidIdentifier(rawValue)
        }
        return id
    }

    private func normalizedQuery(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from record: NativeSyncCachedRecord) -> Value? {
        try? JSONDecoder().decode(type, from: JSONEncoder().encode(record.payload))
    }
}
