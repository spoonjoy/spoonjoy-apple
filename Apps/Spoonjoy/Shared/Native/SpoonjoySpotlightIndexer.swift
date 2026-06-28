import Foundation
import SpoonjoyCore

#if canImport(CoreSpotlight)
import CoreSpotlight

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpotlightIndexer {
    static let searchableTypes: [SpotlightIndexType] = [.recipe, .cookbook, .shoppingListItem]

    func documents(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState,
        scope: SpotlightIndexScope
    ) -> [SpotlightIndexDocument] {
        SpotlightIndexPlan.documents(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList,
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

    func replaceAll(documents: [SpotlightIndexDocument]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        if !documents.isEmpty {
            try await index(documents: documents)
        }
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
}
#endif
