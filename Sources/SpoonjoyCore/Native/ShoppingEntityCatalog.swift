import Foundation

public enum ShoppingEntityKind: String, Codable, Equatable, Sendable {
    case shoppingList
    case shoppingItem
}

public enum ShoppingEntityCatalogError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case unavailableForScope(accountID: String?, environment: NativeCacheEnvironment?)
    case shoppingItemNotFound(String)
    case undecodableRecord(kind: NativeSyncEntryKind, resourceID: String)
}

public struct ShoppingEntityScope: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }

    public var domainIdentifier: String {
        "shopping:\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID)"
    }
}

public struct ShoppingEntityTransferValue: Codable, Equatable, Sendable {
    public let kind: ShoppingEntityKind
    public let rawResourceID: String
    public let title: String
    public let routeIdentifier: String
    public let publicURL: URL?
    public let privateTransferValue: String
    public let userVisibleSummary: String
    public let debugFields: [String]

    public init(
        kind: ShoppingEntityKind,
        rawResourceID: String,
        title: String,
        routeIdentifier: String,
        publicURL: URL?,
        privateTransferValue: String,
        userVisibleSummary: String,
        debugFields: [String] = []
    ) {
        self.kind = kind
        self.rawResourceID = rawResourceID
        self.title = title
        self.routeIdentifier = routeIdentifier
        self.publicURL = publicURL
        self.privateTransferValue = privateTransferValue
        self.userVisibleSummary = userVisibleSummary
        self.debugFields = debugFields
    }
}

public struct ShoppingListEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let scope: ShoppingEntityScope
    public let title: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let activeItemCount: Int
    public let transferValue: ShoppingEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = ShoppingListEntityDescriptor(
        id: "shopping-list-placeholder",
        scope: ShoppingEntityScope(accountID: "placeholder", environment: .production),
        title: "Shopping List",
        subtitle: "Spoonjoy shopping list",
        disambiguationLabel: "Spoonjoy shopping list",
        route: .shoppingList,
        activeItemCount: 0,
        transferValue: ShoppingEntityTransferValue(
            kind: .shoppingList,
            rawResourceID: "shopping-list-placeholder",
            title: "Shopping List",
            routeIdentifier: AppRoute.shoppingList.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.shopping-entity.v1;domain=shopping-list;title=Shopping List",
            userVisibleSummary: "Shopping List"
        )
    )

    public init(scope: ShoppingEntityScope, activeItems: [ShoppingListItem]) {
        let syntheticList = ShoppingListState(
            id: "shopping-list",
            chef: ChefSummary(id: "shopping-list", username: ShoppingEntityCatalog.username(from: scope.accountID)),
            items: activeItems,
            nextCursor: "",
            updatedAt: activeItems.map(\.updatedAt).max() ?? ""
        )
        let payload = NativeSharePayload.privateShoppingList(syntheticList)
        let title = "Shopping List"
        let subtitle = "\(activeItems.count) active \(activeItems.count == 1 ? "item" : "items")"
        self.init(
            id: ShoppingEntityCatalog.shoppingListEntityIdentifier(accountID: scope.accountID, environment: scope.environment),
            scope: scope,
            title: title,
            subtitle: subtitle,
            disambiguationLabel: "Shopping List for \(ShoppingEntityCatalog.username(from: scope.accountID))",
            route: AppRoute.shoppingList,
            activeItemCount: activeItems.count,
            transferValue: ShoppingEntityTransferValue(
                kind: .shoppingList,
                rawResourceID: syntheticList.id,
                title: title,
                routeIdentifier: AppRoute.shoppingList.stateIdentifier,
                publicURL: nil,
                privateTransferValue: payload.serializedTransferValue,
                userVisibleSummary: subtitle
            )
        )
    }

    public init(
        id: String,
        scope: ShoppingEntityScope,
        title: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        activeItemCount: Int,
        transferValue: ShoppingEntityTransferValue
    ) {
        self.id = id
        self.scope = scope
        self.title = title
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.activeItemCount = activeItemCount
        self.transferValue = transferValue
    }
}

public struct ShoppingItemEntityDescriptor: Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let scope: ShoppingEntityScope
    public let title: String
    public let subtitle: String
    public let disambiguationLabel: String
    public let route: AppRoute
    public let checked: Bool
    public let transferValue: ShoppingEntityTransferValue
    public var isPlaceholder: Bool { id == Self.placeholder.id }

    public static let placeholder = ShoppingItemEntityDescriptor(
        id: "shopping-item-placeholder",
        itemID: "shopping-item-placeholder",
        scope: ShoppingEntityScope(accountID: "placeholder", environment: .production),
        title: "Shopping Item",
        subtitle: "Spoonjoy shopping item",
        disambiguationLabel: "Spoonjoy shopping item",
        route: .shoppingList,
        checked: false,
        transferValue: ShoppingEntityTransferValue(
            kind: .shoppingItem,
            rawResourceID: "shopping-item-placeholder",
            title: "Shopping Item",
            routeIdentifier: AppRoute.shoppingList.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.shopping-entity.v1;domain=shopping-item;title=Shopping Item",
            userVisibleSummary: "Shopping Item"
        )
    )

    public init(item: ShoppingListItem, scope: ShoppingEntityScope) {
        let payload = NativeSharePayload.privateShoppingItem(item, listID: "shopping-list")
        self.init(
            id: ShoppingEntityCatalog.shoppingItemEntityIdentifier(itemID: item.id, accountID: scope.accountID, environment: scope.environment),
            itemID: item.id,
            scope: scope,
            title: item.name,
            subtitle: item.displayQuantity,
            disambiguationLabel: "\(item.name) in Shopping List",
            route: .shoppingList,
            checked: item.checked,
            transferValue: ShoppingEntityTransferValue(
                kind: .shoppingItem,
                rawResourceID: item.id,
                title: item.name,
                routeIdentifier: AppRoute.shoppingList.stateIdentifier,
                publicURL: nil,
                privateTransferValue: payload.serializedTransferValue,
                userVisibleSummary: item.displayQuantity.isEmpty ? item.name : "\(item.name), \(item.displayQuantity)"
            )
        )
    }

    public init(
        id: String,
        itemID: String,
        scope: ShoppingEntityScope,
        title: String,
        subtitle: String,
        disambiguationLabel: String,
        route: AppRoute,
        checked: Bool,
        transferValue: ShoppingEntityTransferValue
    ) {
        self.id = id
        self.itemID = itemID
        self.scope = scope
        self.title = title
        self.subtitle = subtitle
        self.disambiguationLabel = disambiguationLabel
        self.route = route
        self.checked = checked
        self.transferValue = transferValue
    }
}

public struct ShoppingEntityIndexPurgePlan: Equatable, Sendable {
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
        shoppingItemIDs: [String]
    ) -> ShoppingEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            shoppingItemIDs: shoppingItemIDs,
            includeDomain: true,
            reason: .accountScopeChanged
        )
    }

    public static func cacheDeletePurge(
        accountID: String,
        environment: NativeCacheEnvironment,
        shoppingItemIDs: [String]
    ) -> ShoppingEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            shoppingItemIDs: shoppingItemIDs,
            includeDomain: false,
            reason: .cacheDeleted
        )
    }

    public static func tombstonePurge(
        tombstones: [NativeSyncTombstone],
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> ShoppingEntityIndexPurgePlan {
        scopedPlan(
            accountID: accountID,
            environment: environment,
            shoppingItemIDs: tombstones.compactMap { tombstone in
                tombstone.resourceType == NativeSyncResourceType.shoppingItem ? tombstone.resourceID : nil
            },
            includeDomain: false,
            reason: .tombstoneApplied
        )
    }

    private static func scopedPlan(
        accountID: String,
        environment: NativeCacheEnvironment,
        shoppingItemIDs: [String],
        includeDomain: Bool,
        reason: Reason
    ) -> ShoppingEntityIndexPurgePlan {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        var identifiers: [String] = []
        identifiers.append(contentsOf: shoppingItemIDs.map { itemID in
            SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: itemID, scope: spotlightScope)
        })
        let domainIdentifiers = includeDomain ? [SpotlightIndexPlan.shoppingListItemDomainIdentifier(scope: spotlightScope)] : []
        return ShoppingEntityIndexPurgePlan(
            identifiers: identifiers,
            domainIdentifiers: domainIdentifiers,
            reason: reason
        )
    }
}

public struct ShoppingEntityCatalog: Sendable {
    private let scope: ShoppingEntityScope?
    private let activeItems: [ShoppingListItem]

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
            activeItems = []
            return
        }

        scope = ShoppingEntityScope(accountID: accountID, environment: environment)
        let tombstonedItems = Set(syncSnapshot.tombstones.compactMap { tombstone in
            tombstone.resourceType == NativeSyncResourceType.shoppingItem ? tombstone.resourceID : nil
        })
        activeItems = syncSnapshot.cachedRecords
            .filter { $0.kind == NativeSyncEntryKind.shoppingItem && !tombstonedItems.contains($0.resourceID) }
            .compactMap { Self.decode(ShoppingListItem.self, from: $0) }
            .filter { $0.deletedAt == nil }
            .sorted { left, right in
                if left.sortIndex == right.sortIndex {
                    return left.id < right.id
                }
                return left.sortIndex < right.sortIndex
            }
    }

    public static func loading(
        syncStore: any NativeSyncStore,
        currentAccountID: String?,
        environment: NativeCacheEnvironment
    ) async throws -> ShoppingEntityCatalog {
        let snapshot = try await syncStore.loadSnapshot()
        return ShoppingEntityCatalog(
            syncSnapshot: snapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    public func shoppingListEntity() async throws -> ShoppingListEntityDescriptor {
        try ShoppingListEntityDescriptor(scope: ensureScopeAvailable(), activeItems: activeItems)
    }

    public func shoppingItemEntity(id: String) async throws -> ShoppingItemEntityDescriptor {
        let scope = try ensureScopeAvailable()
        let itemID = try canonicalRawItemIdentifier(id, scope: scope)
        guard let item = activeItems.first(where: { $0.id == itemID }) else {
            throw ShoppingEntityCatalogError.shoppingItemNotFound(itemID)
        }
        return ShoppingItemEntityDescriptor(item: item, scope: scope)
    }

    public func shoppingItemEntities(for identifiers: [String]) async throws -> [ShoppingItemEntityDescriptor] {
        let scope = try ensureScopeAvailable()
        var entities: [ShoppingItemEntityDescriptor] = []
        for identifier in identifiers {
            guard let itemID = try? Self.resolvedShoppingItemID(
                from: identifier,
                accountID: scope.accountID,
                environment: scope.environment
            ),
            let item = activeItems.first(where: { $0.id == itemID }) else {
                continue
            }
            entities.append(ShoppingItemEntityDescriptor(item: item, scope: scope))
        }
        return entities
    }

    public func shoppingItemEntities(matching string: String) async throws -> [ShoppingItemEntityDescriptor] {
        guard let scope else {
            return []
        }
        let query = normalizedQuery(string)
        let matches = query.isEmpty ? activeItems : activeItems.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
                item.displayQuantity.localizedCaseInsensitiveContains(query)
        }
        return matches.map { ShoppingItemEntityDescriptor(item: $0, scope: scope) }
    }

    public func suggestedShoppingItemEntities(limit: Int = 10) async throws -> [ShoppingItemEntityDescriptor] {
        guard let scope else {
            return []
        }
        return activeItems.prefix(max(0, limit)).map { ShoppingItemEntityDescriptor(item: $0, scope: scope) }
    }

    public static func shoppingListEntityIdentifier(accountID: String, environment: NativeCacheEnvironment) -> String {
        scopedIdentifier(accountID: accountID, environment: environment, resourceKind: "shopping-list", resourceID: "list")
    }

    public static func shoppingItemEntityIdentifier(itemID: String, accountID: String, environment: NativeCacheEnvironment) -> String {
        scopedIdentifier(accountID: accountID, environment: environment, resourceKind: "shopping-item", resourceID: itemID)
    }

    public static func resolvedShoppingItemID(
        from identifier: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> String {
        let parts = identifier.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              parts[0] == "shopping-item",
              parts[1] == environment.rawValue,
              parts[2] == "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)",
              parts[3] == accountID,
              !parts[4].isEmpty
        else {
            throw ShoppingEntityCatalogError.invalidIdentifier(identifier)
        }
        return parts[4]
    }

    public static func purgeEntityIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: ShoppingEntityIndexPurgePlan
    ) -> [String] {
        let spotlightScope = SpotlightIndexScope(accountID: accountID, environment: environment)
        let expectedPrefix = "\(spotlightScope.identifierPrefix)|\(SpotlightIndexType.shoppingListItem.rawValue)|"
        guard plan.identifiers.allSatisfy({ $0.hasPrefix(expectedPrefix) }) else {
            return []
        }
        return plan.identifiers
    }

    public static func purgeDomainIdentifiers(
        accountID: String,
        environment: NativeCacheEnvironment,
        plan: ShoppingEntityIndexPurgePlan
    ) -> [String] {
        let expectedDomain = SpotlightIndexPlan.shoppingListItemDomainIdentifier(
            scope: SpotlightIndexScope(accountID: accountID, environment: environment)
        )
        return plan.domainIdentifiers.filter { $0 == expectedDomain }
    }

    public static func username(from accountID: String) -> String {
        let prefix = "account_"
        guard accountID.hasPrefix(prefix) else {
            return accountID
        }
        return String(accountID.dropFirst(prefix.count))
    }

    private static func scopedIdentifier(
        accountID: String,
        environment: NativeCacheEnvironment,
        resourceKind: String,
        resourceID: String
    ) -> String {
        "\(resourceKind):\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID):\(resourceID)"
    }

    private func ensureScopeAvailable() throws -> ShoppingEntityScope {
        guard let scope else {
            throw ShoppingEntityCatalogError.unavailableForScope(accountID: nil, environment: nil)
        }
        return scope
    }

    private func canonicalRawItemIdentifier(_ rawValue: String, scope: ShoppingEntityScope) throws -> String {
        if let itemID = try? Self.resolvedShoppingItemID(from: rawValue, accountID: scope.accountID, environment: scope.environment) {
            return itemID
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
            throw ShoppingEntityCatalogError.invalidIdentifier(rawValue)
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
