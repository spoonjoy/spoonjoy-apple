import Foundation
import SpoonjoyCore

#if canImport(CoreSpotlight)
import CoreSpotlight
import AppIntents

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpotlightIndexer {
    static let searchableTypes = SpotlightIndexPlan.searchableTypes
    private static let semanticSearchableTypes: [SpotlightIndexType] = [
        .recipe,
        .cookbook,
        .shoppingListItem,
        .spoon,
        .captureDraft,
        .chefProfile
    ]

    func documents(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState,
        spoons: [SpoonEntityDescriptor] = [],
        captureDrafts: [CaptureDraftEntityDescriptor] = [],
        chefProfiles: [ChefProfileEntityDescriptor] = [],
        scope: SpotlightIndexScope
    ) -> [SpotlightIndexDocument] {
        SpotlightIndexPlan.documents(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList,
            spoons: spoons,
            captureDrafts: captureDrafts,
            chefProfiles: chefProfiles,
            scope: scope
        )
    }

    func searchableItem(document: SpotlightIndexDocument) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(itemContentType: "public.data")
        attributes.title = document.title
        attributes.contentDescription = document.contentDescription
        attributes.keywords = document.keywords
        attributes.contentURL = DeepLinkURLBuilder.url(for: document.route)

        return CSSearchableItem(
            uniqueIdentifier: document.uniqueIdentifier,
            domainIdentifier: document.domainIdentifier,
            attributeSet: attributes
        )
    }

    func index(documents: [SpotlightIndexDocument]) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }

        let items = documents.map(searchableItem(document:))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func replaceAll(_ documents: [SpotlightIndexDocument], scope: SpotlightIndexScope) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }

        let domainIdentifiers = SpotlightIndexPlan.domainIdentifiers(scope: scope)
        let index = CSSearchableIndex.default()
        try await deleteSearchableDomainIdentifiers(domainIdentifiers, in: index)
        if !documents.isEmpty {
            try await self.index(documents: documents)
        }
    }

    func replaceAllAppEntities(
        recipes: [SpoonjoyRecipeEntity],
        cookbooks: [SpoonjoyCookbookEntity],
        shoppingLists: [SpoonjoyShoppingListEntity],
        shoppingItems: [SpoonjoyShoppingItemEntity],
        spoons: [SpoonjoySpoonEntity],
        captureDrafts: [SpoonjoyCaptureDraftEntity],
        chefProfiles: [SpoonjoyChefProfileEntity]
    ) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }

        let index = CSSearchableIndex.default()
        try await deleteAllAppEntityTypes(in: index)
        try await indexAppEntities(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingLists: shoppingLists,
            shoppingItems: shoppingItems,
            spoons: spoons,
            captureDrafts: captureDrafts,
            chefProfiles: chefProfiles
        )
    }

    func indexAppEntities(
        recipes: [SpoonjoyRecipeEntity],
        cookbooks: [SpoonjoyCookbookEntity],
        shoppingLists: [SpoonjoyShoppingListEntity],
        shoppingItems: [SpoonjoyShoppingItemEntity],
        spoons: [SpoonjoySpoonEntity],
        captureDrafts: [SpoonjoyCaptureDraftEntity],
        chefProfiles: [SpoonjoyChefProfileEntity]
    ) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }

        let index = CSSearchableIndex.default()
        if !recipes.isEmpty {
            try await index.indexAppEntities(recipes)
        }
        if !cookbooks.isEmpty {
            try await index.indexAppEntities(cookbooks)
        }
        if !shoppingLists.isEmpty {
            try await index.indexAppEntities(shoppingLists)
        }
        if !shoppingItems.isEmpty {
            try await index.indexAppEntities(shoppingItems)
        }
        if !spoons.isEmpty {
            try await index.indexAppEntities(spoons)
        }
        if !captureDrafts.isEmpty {
            try await index.indexAppEntities(captureDrafts)
        }
        if !chefProfiles.isEmpty {
            try await index.indexAppEntities(chefProfiles)
        }
    }

    func delete(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }
        guard !identifiers.isEmpty || !domainIdentifiers.isEmpty else {
            return
        }

        let index = CSSearchableIndex.default()
        if !identifiers.isEmpty {
            try await deleteSearchableItemIdentifiers(identifiers, in: index)
        }

        if !domainIdentifiers.isEmpty {
            try await deleteSearchableDomainIdentifiers(domainIdentifiers, in: index)
        }

        let domainTypes = indexedTypes(matchingDomainIdentifiers: domainIdentifiers)
        let entityIdentifiers = appEntityIdentifiers(
            from: identifiers,
            accountID: accountID,
            environment: environment
        )
        try await deleteAppEntities(
            entityIdentifiers,
            domainTypes: domainTypes,
            in: index
        )
        try await deleteDonations(
            entityIdentifiers,
            domainTypes: domainTypes
        )
    }

    func index(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState,
        scope: SpotlightIndexScope
    ) async throws {
        try await index(documents: documents(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList,
            scope: scope
        ))
    }

    private func deleteSearchableItemIdentifiers(_ identifiers: [String], in index: CSSearchableIndex) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteSearchableDomainIdentifiers(_ domainIdentifiers: [String], in index: CSSearchableIndex) async throws {
        guard !domainIdentifiers.isEmpty else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withDomainIdentifiers: domainIdentifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteAllAppEntityTypes(in index: CSSearchableIndex) async throws {
        try await index.deleteAppEntities(ofType: SpoonjoyRecipeEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoyCookbookEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoyShoppingListEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoyShoppingItemEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoySpoonEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoyCaptureDraftEntity.self)
        try await index.deleteAppEntities(ofType: SpoonjoyChefProfileEntity.self)
    }

    private func deleteAppEntities(
        _ identifiers: AppEntityDeletionIdentifiers,
        domainTypes: Set<SpotlightIndexType>,
        in index: CSSearchableIndex
    ) async throws {
        if domainTypes.contains(.recipe) {
            try await index.deleteAppEntities(ofType: SpoonjoyRecipeEntity.self)
        } else if !identifiers.recipes.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.recipes, ofType: SpoonjoyRecipeEntity.self)
        }

        if domainTypes.contains(.cookbook) {
            try await index.deleteAppEntities(ofType: SpoonjoyCookbookEntity.self)
        } else if !identifiers.cookbooks.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.cookbooks, ofType: SpoonjoyCookbookEntity.self)
        }

        if domainTypes.contains(.shoppingListItem) {
            try await index.deleteAppEntities(ofType: SpoonjoyShoppingListEntity.self)
            try await index.deleteAppEntities(ofType: SpoonjoyShoppingItemEntity.self)
        } else if !identifiers.shoppingItems.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.shoppingItems, ofType: SpoonjoyShoppingItemEntity.self)
        }

        if domainTypes.contains(.spoon) {
            try await index.deleteAppEntities(ofType: SpoonjoySpoonEntity.self)
        } else if !identifiers.spoons.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.spoons, ofType: SpoonjoySpoonEntity.self)
        }

        if domainTypes.contains(.captureDraft) {
            try await index.deleteAppEntities(ofType: SpoonjoyCaptureDraftEntity.self)
        } else if !identifiers.captureDrafts.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.captureDrafts, ofType: SpoonjoyCaptureDraftEntity.self)
        }

        if domainTypes.contains(.chefProfile) {
            try await index.deleteAppEntities(ofType: SpoonjoyChefProfileEntity.self)
        } else if !identifiers.chefProfiles.isEmpty {
            try await index.deleteAppEntities(identifiedBy: identifiers.chefProfiles, ofType: SpoonjoyChefProfileEntity.self)
        }
    }

    private func deleteDonations(
        _ identifiers: AppEntityDeletionIdentifiers,
        domainTypes: Set<SpotlightIndexType>
    ) async throws {
        let donor = SpoonjoyInteractionDonor()
        for id in identifiers.recipes {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoyRecipeEntity.self, identifier: id))
        }
        for id in identifiers.cookbooks {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoyCookbookEntity.self, identifier: id))
        }
        for id in identifiers.shoppingItems {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoyShoppingItemEntity.self, identifier: id))
        }
        for id in identifiers.spoons {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoySpoonEntity.self, identifier: id))
        }
        for id in identifiers.captureDrafts {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoyCaptureDraftEntity.self, identifier: id))
        }
        for id in identifiers.chefProfiles {
            try await donor.deleteDonations(matching: EntityIdentifier(for: SpoonjoyChefProfileEntity.self, identifier: id))
        }

        if domainTypes.contains(.recipe) {
            try await donor.deleteDonations(matching: OpenRecipeIntent.self)
            try await donor.deleteDonations(matching: StartCookModeIntent.self)
            try await donor.deleteDonations(matching: AddRecipeIngredientsToShoppingListIntent.self)
        }
        if domainTypes.contains(.shoppingListItem) {
            try await donor.deleteDonations(matching: AddShoppingListItemIntent.self)
            try await donor.deleteDonations(matching: SetShoppingListItemCheckedIntent.self)
            try await donor.deleteDonations(matching: ClearCompletedShoppingItemsIntent.self)
            try await donor.deleteDonations(matching: ClearShoppingListIntent.self)
        }
        if domainTypes.contains(.captureDraft) {
            try await donor.deleteDonations(matching: CaptureRecipeIntent.self)
        }
    }

    private func indexedTypes(matchingDomainIdentifiers domainIdentifiers: [String]) -> Set<SpotlightIndexType> {
        Set(Self.searchableTypes.filter { type in
            domainIdentifiers.contains { domainIdentifier in
                domainIdentifier.hasSuffix(".\(type.rawValue)")
            }
        })
    }

    private func appEntityIdentifiers(
        from identifiers: [String],
        accountID: String?,
        environment: NativeCacheEnvironment?
    ) -> AppEntityDeletionIdentifiers {
        guard let accountID,
              let environment else {
            return AppEntityDeletionIdentifiers()
        }

        let scope = SpotlightIndexScope(accountID: accountID, environment: environment)
        var result = AppEntityDeletionIdentifiers()
        for identifier in identifiers {
            guard let parsed = parsedSpotlightIdentifier(identifier, scope: scope) else {
                continue
            }
            switch parsed.type {
            case .recipe:
                result.recipes.append(RecipeCookbookEntityCatalog.recipeEntityIdentifier(
                    recipeID: parsed.resourceID,
                    accountID: accountID,
                    environment: environment
                ))
            case .cookbook:
                result.cookbooks.append(RecipeCookbookEntityCatalog.cookbookEntityIdentifier(
                    cookbookID: parsed.resourceID,
                    accountID: accountID,
                    environment: environment
                ))
            case .shoppingListItem:
                result.shoppingItems.append(ShoppingEntityCatalog.shoppingItemEntityIdentifier(
                    itemID: parsed.resourceID,
                    accountID: accountID,
                    environment: environment
                ))
            case .spoon:
                result.spoons.append(SpoonEntityCatalog.spoonEntityIdentifier(
                    spoonID: parsed.resourceID,
                    accountID: accountID,
                    environment: environment
                ))
            case .captureDraft:
                result.captureDrafts.append(CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
                    draftID: parsed.resourceID,
                    accountID: accountID,
                    environment: environment
                ))
            case .chefProfile:
                result.chefProfiles.append(parsed.resourceID)
            }
        }

        result.deduplicate()
        return result
    }

    private func parsedSpotlightIdentifier(
        _ identifier: String,
        scope: SpotlightIndexScope
    ) -> (type: SpotlightIndexType, resourceID: String)? {
        let parts = identifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              "\(parts[0])|\(parts[1])|\(parts[2])" == scope.identifierPrefix,
              let type = SpotlightIndexType(rawValue: parts[3]) else {
            return nil
        }

        let rawResourceID = parts[4]
        switch type {
        case .spoon:
            let routeParts = rawResourceID.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard !rawResourceID.isEmpty else { return nil }
            return (type, routeParts.first ?? rawResourceID)
        case .recipe,
             .cookbook,
             .shoppingListItem,
             .captureDraft,
             .chefProfile:
            guard !rawResourceID.isEmpty else { return nil }
            return (type, rawResourceID)
        }
    }
}

private struct AppEntityDeletionIdentifiers {
    var recipes: [String] = []
    var cookbooks: [String] = []
    var shoppingItems: [String] = []
    var spoons: [String] = []
    var captureDrafts: [String] = []
    var chefProfiles: [String] = []

    mutating func deduplicate() {
        recipes = Self.uniquePreservingOrder(recipes)
        cookbooks = Self.uniquePreservingOrder(cookbooks)
        shoppingItems = Self.uniquePreservingOrder(shoppingItems)
        spoons = Self.uniquePreservingOrder(spoons)
        captureDrafts = Self.uniquePreservingOrder(captureDrafts)
        chefProfiles = Self.uniquePreservingOrder(chefProfiles)
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
#endif
