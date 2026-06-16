import Foundation

#if canImport(CoreSpotlight)
import CoreSpotlight

@available(iOS 27.0, macOS 27.0, *)
struct SpoonjoySpotlightIndexer {
    enum IndexedType: String, CaseIterable {
        case recipe
        case cookbook
        case shoppingListItem = "shopping-list-item"
    }

    func searchableItem(
        id: String,
        type: IndexedType,
        title: String,
        summary: String
    ) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(itemContentType: "public.data")
        attributes.title = title
        attributes.contentDescription = summary
        attributes.keywords = [type.rawValue, "Spoonjoy"]

        return CSSearchableItem(
            uniqueIdentifier: "\(type.rawValue):\(id)",
            domainIdentifier: "app.spoonjoy.\(type.rawValue)",
            attributeSet: attributes
        )
    }
}
#endif
