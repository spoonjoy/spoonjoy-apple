import Foundation

public enum KitchenStateError: Error, Equatable, CustomStringConvertible {
    case itemNotFound(String)
    case emptyItemName
    case missingCookModeStep(String)
    case missingCookModeIngredient(String)
    case missingCookModeStepOutputUse(String)

    public var description: String {
        switch self {
        case .itemNotFound(let id):
            "Shopping list item \(id) was not found."
        case .emptyItemName:
            "Shopping list item name must be non-empty."
        case .missingCookModeStep(let id):
            "Cook mode step \(id) was not found."
        case .missingCookModeIngredient(let id):
            "Cook mode ingredient \(id) was not found."
        case .missingCookModeStepOutputUse(let id):
            "Cook mode step output use \(id) was not found."
        }
    }
}

public struct ShoppingListItem: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Double?
    public let unit: String?
    public let checked: Bool
    public let checkedAt: String?
    public let deletedAt: String?
    public let categoryKey: String?
    public let iconKey: String?
    public let sortIndex: Int
    public let updatedAt: String

    public var displayQuantity: String {
        guard let quantity else {
            return unit ?? ""
        }

        let formattedQuantity = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(quantity))
            : String(quantity)

        guard let unit, !unit.isEmpty else {
            return formattedQuantity
        }

        return "\(formattedQuantity) \(unit)"
    }

    func settingChecked(_ checked: Bool, checkedAt: String?, updatedAt: String, nextSortIndex: Int) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: checked,
            checkedAt: checked ? checkedAt : nil,
            deletedAt: nil,
            categoryKey: categoryKey,
            iconKey: iconKey,
            sortIndex: checked ? nextSortIndex : sortIndex,
            updatedAt: updatedAt
        )
    }

    func removing(deletedAt: String) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: checked,
            checkedAt: checkedAt,
            deletedAt: deletedAt,
            categoryKey: categoryKey,
            iconKey: iconKey,
            sortIndex: sortIndex,
            updatedAt: deletedAt
        )
    }

    func merging(
        quantity addedQuantity: Double?,
        categoryKey: String?,
        iconKey: String?,
        restoredSortIndex: Int?
    ) -> ShoppingListItem {
        let mergedQuantity: Double?

        if let addedQuantity {
            mergedQuantity = (quantity ?? 0) + addedQuantity
        } else {
            mergedQuantity = quantity
        }

        return ShoppingListItem(
            id: id,
            name: name,
            quantity: mergedQuantity,
            unit: unit,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: categoryKey ?? self.categoryKey,
            iconKey: iconKey ?? self.iconKey,
            sortIndex: restoredSortIndex ?? sortIndex,
            updatedAt: updatedAt
        )
    }
}

public struct ShoppingListReceiptSection: Equatable, Sendable {
    public let title: String
    public let items: [ShoppingListItem]
}

public struct ShoppingListMutationMetadata: Codable, Equatable, Sendable {
    public let clientMutationID: String
    public let replayed: Bool

    public init(clientMutationID: String, replayed: Bool) {
        self.clientMutationID = clientMutationID
        self.replayed = replayed
    }

    private enum CodingKeys: String, CodingKey {
        case clientMutationID = "clientMutationId"
        case replayed
    }
}

public struct ShoppingListMutationResult: Equatable, Sendable {
    public let created: Bool
    public let updated: Bool
    public let shoppingList: ShoppingListState
    public let mutation: ShoppingListMutationMetadata
}

public struct ShoppingListState: Codable, Equatable, Sendable {
    public let id: String
    public let chef: ChefSummary
    public let items: [ShoppingListItem]
    public let nextCursor: String
    public let updatedAt: String

    public static func decodeFromBundle() throws -> ShoppingListState {
        try JSONDecoder().decode(ShoppingListState.self, from: SpoonjoyFixture.data(named: "shopping-list-fixture"))
    }

    public var activeItems: [ShoppingListItem] {
        items
            .filter { $0.deletedAt == nil }
            .sorted { left, right in
                if left.sortIndex == right.sortIndex {
                    return left.id < right.id
                }

                return left.sortIndex < right.sortIndex
            }
    }

    public var receiptSections: [ShoppingListReceiptSection] {
        var orderedKeys: [String?] = []
        var groupedItems: [String?: [ShoppingListItem]] = [:]

        for item in activeItems {
            let key = item.categoryKey
            if groupedItems[key] == nil {
                orderedKeys.append(key)
                groupedItems[key] = []
            }
            groupedItems[key]?.append(item)
        }

        return orderedKeys.map { key in
            ShoppingListReceiptSection(
                title: Self.sectionTitle(for: key),
                items: groupedItems[key]!
            )
        }
    }

    public func item(id: String) -> ShoppingListItem? {
        items.first { $0.id == id }
    }

    public func settingChecked(
        _ checked: Bool,
        itemID: String,
        checkedAt: String?,
        updatedAt: String,
        nextSortIndex: Int
    ) throws -> ShoppingListState {
        try replacingItem(id: itemID) { item in
            item.settingChecked(checked, checkedAt: checkedAt, updatedAt: updatedAt, nextSortIndex: nextSortIndex)
        }
    }

    public func removingItem(id: String, deletedAt: String) throws -> ShoppingListState {
        try replacingItem(id: id) { item in
            item.removing(deletedAt: deletedAt)
        }
    }

    public func addingOrRestoringItem(
        name: String,
        quantity: Double?,
        unit: String?,
        categoryKey: String?,
        iconKey: String?,
        clientMutationID: String
    ) throws -> ShoppingListMutationResult {
        let normalizedName = Self.normalizedName(name)
        guard !normalizedName.isEmpty else {
            throw KitchenStateError.emptyItemName
        }
        let normalizedUnit = Self.normalizedOptionalName(unit)

        let matchIndex = items.firstIndex { item in
            Self.normalizedName(item.name) == normalizedName &&
                Self.normalizedOptionalName(item.unit) == normalizedUnit
        }

        let mutation = ShoppingListMutationMetadata(clientMutationID: clientMutationID, replayed: false)

        guard let matchIndex else {
            let newItem = ShoppingListItem(
                id: "item_local_\(clientMutationID)",
                name: normalizedName,
                quantity: quantity,
                unit: normalizedUnit,
                checked: false,
                checkedAt: nil,
                deletedAt: nil,
                categoryKey: categoryKey,
                iconKey: iconKey,
                sortIndex: nextActiveSortIndex(),
                updatedAt: updatedAt
            )
            return ShoppingListMutationResult(
                created: true,
                updated: false,
                shoppingList: ShoppingListState(
                    id: id,
                    chef: chef,
                    items: items + [newItem],
                    nextCursor: nextCursor,
                    updatedAt: updatedAt
                ),
                mutation: mutation
            )
        }

        var updatedItems = items
        let matchedItem = items[matchIndex]
        let shouldRestoreToTail = matchedItem.checked || matchedItem.checkedAt != nil || matchedItem.deletedAt != nil
        updatedItems[matchIndex] = items[matchIndex].merging(
            quantity: quantity,
            categoryKey: categoryKey,
            iconKey: iconKey,
            restoredSortIndex: shouldRestoreToTail ? nextActiveSortIndex() : nil
        )

        return ShoppingListMutationResult(
            created: false,
            updated: true,
            shoppingList: ShoppingListState(
                id: id,
                chef: chef,
                items: updatedItems,
                nextCursor: nextCursor,
                updatedAt: updatedAt
            ),
            mutation: mutation
        )
    }

    private func replacingItem(
        id itemID: String,
        replacement: (ShoppingListItem) -> ShoppingListItem
    ) throws -> ShoppingListState {
        guard let itemIndex = items.firstIndex(where: { $0.id == itemID }) else {
            throw KitchenStateError.itemNotFound(itemID)
        }

        var updatedItems = items
        updatedItems[itemIndex] = replacement(items[itemIndex])

        return ShoppingListState(
            id: id,
            chef: chef,
            items: updatedItems,
            nextCursor: nextCursor,
            updatedAt: updatedAt
        )
    }

    private static func sectionTitle(for categoryKey: String?) -> String {
        guard let categoryKey, !categoryKey.isEmpty else {
            return "Other"
        }

        return categoryKey
            .split(separator: "-")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func nextActiveSortIndex() -> Int {
        (activeItems.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedOptionalName(_ value: String?) -> String? {
        guard let normalized = value.map(normalizedName), !normalized.isEmpty else {
            return nil
        }

        return normalized
    }
}
