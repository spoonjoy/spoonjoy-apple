import Foundation

public enum SpoonEntityKind: String, Codable, Equatable, Sendable {
    case spoon
}

public enum SpoonEntityCatalogError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case unavailableForScope(accountID: String?, environment: NativeCacheEnvironment?)
    case spoonNotFound(String)
    case undecodableRecord(kind: NativeSyncEntryKind, resourceID: String)
}

public struct SpoonEntityScope: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }

    public var domainIdentifier: String {
        "spoon:\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID)"
    }
}

public struct SpoonEntityTransferValue: Codable, Equatable, Sendable {
    public let kind: SpoonEntityKind
    public let rawResourceID: String
    public let recipeID: String
    public let recipeTitle: String
    public let title: String
    public let routeIdentifier: String
    public let publicURL: URL?
    public let privateTransferValue: String
    public let userVisibleSummary: String
    public let debugFields: [String]

    public init(
        kind: SpoonEntityKind,
        rawResourceID: String,
        recipeID: String,
        recipeTitle: String,
        title: String,
        routeIdentifier: String,
        publicURL: URL?,
        privateTransferValue: String,
        userVisibleSummary: String,
        debugFields: [String] = []
    ) {
        self.kind = kind
        self.rawResourceID = rawResourceID
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.title = title
        self.routeIdentifier = routeIdentifier
        self.publicURL = publicURL
        self.privateTransferValue = privateTransferValue
        self.userVisibleSummary = userVisibleSummary
        self.debugFields = debugFields
    }
}

public struct SpoonEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let spoonID: String
    public let recipeID: String
    public let recipeTitle: String
    public let chefID: String
    public let chefUsername: String
    public let title: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let photoURL: URL?
    public let note: String?
    public let nextTime: String?
    public let cookedAt: String?
    public let transferValue: SpoonEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = SpoonEntityDescriptor(
        id: "spoon-placeholder",
        spoonID: "spoon-placeholder",
        recipeID: "recipe-placeholder",
        recipeTitle: "Recipe",
        chefID: "chef-placeholder",
        chefUsername: "Spoonjoy",
        title: "Recipe cook log",
        subtitle: "Spoonjoy cook log",
        disambiguationLabel: "Spoonjoy cook log",
        route: .recipeDetail(id: "recipe-placeholder", presentation: .detail),
        photoURL: nil,
        note: nil,
        nextTime: nil,
        cookedAt: nil,
        transferValue: SpoonEntityTransferValue(
            kind: .spoon,
            rawResourceID: "spoon-placeholder",
            recipeID: "recipe-placeholder",
            recipeTitle: "Recipe",
            title: "Recipe cook log",
            routeIdentifier: AppRoute.recipeDetail(id: "recipe-placeholder", presentation: .detail).stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.spoon-entity.v1;domain=spoon;title=Recipe cook log",
            userVisibleSummary: "Spoonjoy cook log"
        )
    )

    public init(spoon: RecipeDetailRecentSpoon, recipe: Recipe, scope: SpoonEntityScope) {
        let route = AppRoute.recipeDetail(id: spoon.recipeID, presentation: .detail)
        let payload = NativeSharePayload.privateSpoon(spoon, recipeTitle: recipe.title)
        let title = "\(recipe.title) cook log"
        let subtitle = Self.subtitle(for: spoon)
        self.init(
            id: SpoonEntityCatalog.spoonEntityIdentifier(spoonID: spoon.id, accountID: scope.accountID, environment: scope.environment),
            spoonID: spoon.id,
            recipeID: spoon.recipeID,
            recipeTitle: recipe.title,
            chefID: spoon.chefID,
            chefUsername: spoon.chef.username,
            title: title,
            subtitle: subtitle,
            disambiguationLabel: "\(recipe.title) by \(spoon.chef.username)",
            route: route,
            photoURL: spoon.photoURL,
            note: spoon.note,
            nextTime: spoon.nextTime,
            cookedAt: spoon.cookedAt,
            transferValue: SpoonEntityTransferValue(
                kind: .spoon,
                rawResourceID: spoon.id,
                recipeID: spoon.recipeID,
                recipeTitle: recipe.title,
                title: title,
                routeIdentifier: route.stateIdentifier,
                publicURL: nil,
                privateTransferValue: payload.serializedTransferValue,
                userVisibleSummary: "\(recipe.title): \(subtitle)"
            )
        )
    }

    public init(
        id: String,
        spoonID: String,
        recipeID: String,
        recipeTitle: String,
        chefID: String,
        chefUsername: String,
        title: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        photoURL: URL?,
        note: String?,
        nextTime: String?,
        cookedAt: String?,
        transferValue: SpoonEntityTransferValue
    ) {
        self.id = id
        self.spoonID = spoonID
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.chefID = chefID
        self.chefUsername = chefUsername
        self.title = title
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.photoURL = photoURL
        self.note = note
        self.nextTime = nextTime
        self.cookedAt = cookedAt
        self.transferValue = transferValue
    }

    private static func subtitle(for spoon: RecipeDetailRecentSpoon) -> String {
        let note = spoon.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note, !note.isEmpty {
            return note
        }
        if let cookedAt = spoon.cookedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !cookedAt.isEmpty {
            return "Cooked \(cookedAt)"
        }
        if let nextTime = spoon.nextTime?.trimmingCharacters(in: .whitespacesAndNewlines), !nextTime.isEmpty {
            return "Next time: \(nextTime)"
        }
        return "Cook log"
    }
}

public struct SpoonEntityIndexPurgePlan: Equatable, Sendable {
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
        spoonIDs: [String]
    ) -> SpoonEntityIndexPurgePlan {
        scopedPlan(accountID: accountID, environment: environment, spoonIDs: spoonIDs, reason: .accountScopeChanged)
    }

    public static func cacheDeletePurge(
        accountID: String,
        environment: NativeCacheEnvironment,
        spoonIDs: [String]
    ) -> SpoonEntityIndexPurgePlan {
        scopedPlan(accountID: accountID, environment: environment, spoonIDs: spoonIDs, reason: .cacheDeleted)
    }

    public static func tombstonePurge(
        tombstones: [NativeSyncTombstone],
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> SpoonEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            spoonIDs: tombstones.compactMap { tombstone in
                tombstone.resourceType == NativeSyncResourceType.spoon ? tombstone.resourceID : nil
            },
            reason: .tombstoneApplied
        )
    }

    private static func scopedPlan(
        accountID: String,
        environment: NativeCacheEnvironment,
        spoonIDs: [String],
        reason: Reason
    ) -> SpoonEntityIndexPurgePlan {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let identifiers = spoonIDs.map { spoonID in
            SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: spoonID, scope: spotlightScope)
        }
        let domainIdentifiers = [SpotlightIndexPlan.spoonDomainIdentifier(scope: spotlightScope)]
        return SpoonEntityIndexPurgePlan(identifiers: identifiers, domainIdentifiers: domainIdentifiers, reason: reason)
    }
}

public struct SpoonEntityCatalog: Sendable {
    private let scope: SpoonEntityScope?
    private let records: [SpoonRecord]

    public init(
        syncSnapshot: NativeSyncSnapshot,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) {
        guard syncSnapshot.accountID == currentAccountID,
              syncSnapshot.environment == environment,
              let accountID = currentAccountID
        else {
            scope = nil
            records = []
            return
        }

        scope = SpoonEntityScope(accountID: accountID, environment: environment)
        let tombstonedSpoons = Set(syncSnapshot.tombstones.compactMap { tombstone in
            tombstone.resourceType == NativeSyncResourceType.spoon ? tombstone.resourceID : nil
        })
        let recipes = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.recipe }
            .compactMap { Self.decode(Recipe.self, from: $0) }
        let recipeByID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        let spoonRecords = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.spoon && !tombstonedSpoons.contains($0.resourceID) }
            .compactMap { record -> RecipeDetailRecentSpoon? in
                Self.decode(RecipeDetailRecentSpoon.self, from: record)
            }
        let recipeSpoons = recipes.flatMap(\.recentSpoons)
        let dedupedSpoons = Self.uniqueSpoons(spoonRecords + recipeSpoons)
            .filter { $0.deletedAt == nil && !tombstonedSpoons.contains($0.id) }
        records = dedupedSpoons.compactMap { spoon in
            guard let recipe = recipeByID[spoon.recipeID] else {
                return nil
            }
            return SpoonRecord(spoon: spoon, recipe: recipe)
        }
        .sorted(by: Self.sortRecords)
    }

    public static func loading(
        syncStore: any NativeSyncStore,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) async throws -> SpoonEntityCatalog {
        let snapshot = try await syncStore.loadSnapshot()
        return SpoonEntityCatalog(syncSnapshot: snapshot, currentAccountID: currentAccountID, environment: environment)
    }

    public func spoonEntity(id: String) async throws -> SpoonEntityDescriptor {
        let scope = try ensureScopeAvailable()
        let spoonID = try canonicalRawSpoonIdentifier(id, scope: scope)
        guard let record = records.first(where: { $0.spoon.id == spoonID }) else {
            throw SpoonEntityCatalogError.spoonNotFound(spoonID)
        }
        return SpoonEntityDescriptor(spoon: record.spoon, recipe: record.recipe, scope: scope)
    }

    public func spoonEntities(for identifiers: [String]) async throws -> [SpoonEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        var entities: [SpoonEntityDescriptor] = []
        for identifier in identifiers {
            guard let spoonID = try? Self.resolvedSpoonID(from: identifier, accountID: scope.accountID, environment: scope.environment),
                  let record = records.first(where: { $0.spoon.id == spoonID }) else {
                continue
            }
            entities.append(SpoonEntityDescriptor(spoon: record.spoon, recipe: record.recipe, scope: scope))
        }
        return entities
    }

    public func spoonEntities(matching string: String) async throws -> [SpoonEntityDescriptor] {
        guard let scope else {
            return []
        }
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? records : records.filter { record in
            record.recipe.title.localizedCaseInsensitiveContains(query) ||
                record.spoon.note?.localizedCaseInsensitiveContains(query) == true ||
                record.spoon.nextTime?.localizedCaseInsensitiveContains(query) == true ||
                record.spoon.chef.username.localizedCaseInsensitiveContains(query)
        }
        return matches.map { SpoonEntityDescriptor(spoon: $0.spoon, recipe: $0.recipe, scope: scope) }
    }

    public func suggestedSpoonEntities(limit: Int = 10) async throws -> [SpoonEntityDescriptor] {
        guard let scope else {
            return []
        }
        return records.prefix(max(0, limit)).map { SpoonEntityDescriptor(spoon: $0.spoon, recipe: $0.recipe, scope: scope) }
    }

    public static func spoonEntityIdentifier(spoonID: String, accountID: String, environment: NativeCacheEnvironment) -> String {
        "spoon:\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID):\(spoonID)"
    }

    public static func resolvedSpoonID(
        from identifier: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> String {
        let parts = identifier.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              parts[0] == "spoon",
              parts[1] == environment.rawValue,
              parts[2] == "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)",
              parts[3] == accountID,
              !parts[4].isEmpty
        else {
            throw SpoonEntityCatalogError.invalidIdentifier(identifier)
        }
        return parts[4]
    }

    public static func purgeEntityIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: SpoonEntityIndexPurgePlan
    ) -> [String] {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let expectedPrefix = "\(spotlightScope.identifierPrefix)|\(SpotlightIndexType.spoon.rawValue)|"
        guard plan.identifiers.allSatisfy({ $0.hasPrefix(expectedPrefix) }) else {
            return []
        }
        return plan.identifiers
    }

    public static func purgeDomainIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: SpoonEntityIndexPurgePlan
    ) -> [String] {
        let expectedDomain = SpotlightIndexPlan.spoonDomainIdentifier(
            scope: SpotlightIndexScope(accountID: accountID, environment: environment)
        )
        return plan.domainIdentifiers.filter { $0 == expectedDomain }
    }

    private func ensureScopeAvailable() throws -> SpoonEntityScope {
        guard let scope else {
            throw SpoonEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
        return scope
    }

    private func canonicalRawSpoonIdentifier(_ rawValue: String, scope: SpoonEntityScope) throws -> String {
        if let spoonID = try? Self.resolvedSpoonID(from: rawValue, accountID: scope.accountID, environment: scope.environment) {
            return spoonID
        }

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
            throw SpoonEntityCatalogError.invalidIdentifier(rawValue)
        }
        return id
    }

    private func normalizedQuery(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueSpoons(_ spoons: [RecipeDetailRecentSpoon]) -> [RecipeDetailRecentSpoon] {
        var seen = Set<String>()
        var unique: [RecipeDetailRecentSpoon] = []
        for spoon in spoons where seen.insert(spoon.id).inserted {
            unique.append(spoon)
        }
        return unique
    }

    private static func sortRecords(_ lhs: SpoonRecord, _ rhs: SpoonRecord) -> Bool {
        let leftDate = lhs.spoon.cookedAt ?? lhs.spoon.updatedAt
        let rightDate = rhs.spoon.cookedAt ?? rhs.spoon.updatedAt
        if leftDate == rightDate {
            return lhs.spoon.id < rhs.spoon.id
        }
        return leftDate > rightDate
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from record: NativeSyncCachedRecord) -> Value? {
        try? JSONDecoder().decode(type, from: JSONEncoder().encode(record.payload))
    }
}

private struct SpoonRecord: Sendable {
    let spoon: RecipeDetailRecentSpoon
    let recipe: Recipe
}
