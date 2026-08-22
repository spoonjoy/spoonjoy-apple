import Foundation

public enum ShoppingListViewMode: String, CaseIterable, Equatable, Sendable {
    case need
    case basket
    case all
}

public struct ShoppingModeOption: Equatable, Sendable {
    public let mode: ShoppingListViewMode
    public let label: String

    public init(mode: ShoppingListViewMode, label: String) {
        self.mode = mode
        self.label = label
    }
}

public struct ShoppingPresentationItem: Equatable, Sendable, Identifiable {
    public let item: ShoppingListItem
    public let categoryKey: String
    public let categoryLabel: String
    public let iconKey: String

    public var id: String { item.id }
}

public struct ShoppingPresentationSection: Equatable, Sendable, Identifiable {
    public let title: String
    public let items: [ShoppingPresentationItem]

    public var id: String { title }
}

public struct ShoppingPresentationModel: Equatable, Sendable {
    public let mode: ShoppingListViewMode
    public let activeCategory: String
    public let modeOptions: [ShoppingModeOption]
    public let categoryOptions: [String]
    public let visibleItems: [ShoppingPresentationItem]
    public let sections: [ShoppingPresentationSection]
    public let emptyTitle: String?
    public let emptyMessage: String?

    public init(
        shoppingList: ShoppingListState,
        mode: ShoppingListViewMode = .all,
        activeCategory requestedCategory: String = "all"
    ) {
        let allItems = Self.marketItems(from: shoppingList)
        let checkedCount = allItems.lazy.filter { $0.item.isEffectivelyChecked }.count
        let uncheckedCount = allItems.count - checkedCount
        let modeItems = allItems.filter { presentationItem in
            let isChecked = presentationItem.item.isEffectivelyChecked
            return switch mode {
            case .need: !isChecked
            case .basket: isChecked
            case .all: true
            }
        }
        var categoryOptions = ["all"]
        for item in modeItems where !categoryOptions.contains(item.categoryLabel) {
            categoryOptions.append(item.categoryLabel)
        }
        let activeCategory = categoryOptions.contains(requestedCategory) ? requestedCategory : "all"
        let visibleItems = activeCategory == "all"
            ? modeItems
            : modeItems.filter { $0.categoryLabel == activeCategory }

        self.mode = mode
        self.activeCategory = activeCategory
        modeOptions = [
            ShoppingModeOption(mode: .need, label: "Need \(uncheckedCount)"),
            ShoppingModeOption(mode: .basket, label: "Basket \(checkedCount)"),
            ShoppingModeOption(mode: .all, label: "All \(allItems.count)"),
        ]
        self.categoryOptions = categoryOptions
        self.visibleItems = visibleItems
        sections = Self.sections(from: visibleItems)

        if allItems.isEmpty {
            emptyTitle = "Your shopping list is empty"
            emptyMessage = "Add items manually or add all ingredients from a recipe."
        } else if visibleItems.isEmpty {
            emptyTitle = mode == .basket ? "Nothing in the basket yet" : "Nothing left in this view"
            emptyMessage = "Switch views or categories to see the rest of your shopping list."
        } else {
            emptyTitle = nil
            emptyMessage = nil
        }
    }

    private static let categoryRank = [
        "Produce": 1,
        "Protein": 2,
        "Dairy": 3,
        "Bakery": 4,
        "Pantry": 5,
        "Spices": 6,
        "Frozen": 7,
        "Other": 8,
    ]

    private static let categoryLabels = [
        "produce": "Produce",
        "protein": "Protein",
        "dairy": "Dairy",
        "bakery": "Bakery",
        "pantry": "Pantry",
        "spices": "Spices",
        "frozen": "Frozen",
        "other": "Other",
    ]

    private static func marketItems(from shoppingList: ShoppingListState) -> [ShoppingPresentationItem] {
        shoppingList.items
            .filter { $0.deletedAt == nil }
            .enumerated()
            .map { index, item in
                let affordance = affordance(for: item)
                return (index, ShoppingPresentationItem(
                    item: item,
                    categoryKey: affordance.categoryKey,
                    categoryLabel: affordance.categoryLabel,
                    iconKey: affordance.iconKey
                ))
            }
            .sorted { left, right in
                let leftRank = categoryRank[left.1.categoryLabel] ?? 99
                let rightRank = categoryRank[right.1.categoryLabel] ?? 99
                return leftRank == rightRank ? left.0 < right.0 : leftRank < rightRank
            }
            .map(\.1)
    }

    private static func sections(from items: [ShoppingPresentationItem]) -> [ShoppingPresentationSection] {
        var result: [ShoppingPresentationSection] = []
        for item in items {
            if result.last?.title == item.categoryLabel {
                let previous = result.removeLast()
                result.append(ShoppingPresentationSection(title: previous.title, items: previous.items + [item]))
            } else {
                result.append(ShoppingPresentationSection(title: item.categoryLabel, items: [item]))
            }
        }
        return result
    }

    private static func affordance(for item: ShoppingListItem) -> (categoryKey: String, categoryLabel: String, iconKey: String) {
        let inferred = inferredAffordance(for: item.name)
        let categoryKey = item.categoryKey.flatMap { categoryLabels[$0] == nil ? nil : $0 } ?? inferred.categoryKey
        let iconKey = validSpecificIcon(item.iconKey) ?? inferred.iconKey
        return (categoryKey, categoryLabels[categoryKey] ?? "Other", iconKey)
    }

    private static func validSpecificIcon(_ iconKey: String?) -> String? {
        let valid = Set(["leaf", "carrot", "citrus", "apple", "drumstick", "beef", "fish", "egg", "milk", "wheat", "droplets", "pot", "sandwich"])
        guard let iconKey, valid.contains(iconKey) else { return nil }
        return iconKey
    }

    private static func inferredAffordance(for name: String) -> (categoryKey: String, iconKey: String) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rules: [([String], String, String)] = [
            (["tomato paste"], "pantry", "package"),
            (["basil", "cilantro", "parsley", "dill", "chive", "sage", "lettuce", "spinach", "kale", "arugula", "herb"], "produce", "leaf"),
            (["lime", "lemon", "orange", "grapefruit", "citrus"], "produce", "citrus"),
            (["carrot", "onion", "garlic", "tomato", "potato", "broccoli", "cauliflower", "zucchini", "cucumber", "celery", "fennel", "eggplant", "cabbage", "radicchio"], "produce", "carrot"),
            (["apple", "banana", "berry", "avocado", "mango"], "produce", "apple"),
            (["chicken", "thigh", "drumstick", "wing"], "protein", "drumstick"),
            (["beef", "steak", "pork", "lamb", "sausage", "turkey"], "protein", "beef"),
            (["salmon", "tuna", "cod", "fish", "shrimp", "prawn"], "protein", "fish"),
            (["egg"], "protein", "egg"),
            (["tofu", "tempeh", "beans", "lentil", "chickpea"], "protein", "package"),
            (["coconut milk"], "pantry", "package"),
            (["flour", "rice", "oat", "pasta", "noodle", "quinoa", "sugar"], "pantry", "wheat"),
            (["oil", "vinegar", "broth", "stock", "water", "soy sauce", "tamari", "sauce"], "pantry", "droplets"),
            (["can", "jar", "coconut cream", "miso", "curry paste", "walnut", "pistachio", "sesame", "seed"], "pantry", "package"),
            (["milk", "cream", "yogurt", "cheese", "butter", "half and half", "mozzarella", "ricotta", "feta", "parmesan", "cheddar"], "dairy", "milk"),
            (["bread", "bun", "tortilla", "bagel", "pita"], "bakery", "sandwich"),
            (["frozen"], "frozen", "package"),
            (["salt", "pepper", "cumin", "paprika", "oregano", "thyme", "spice", "seasoning"], "spices", "pot"),
        ]
        for (keywords, category, icon) in rules where keywords.contains(where: value.contains) {
            return (category, icon)
        }
        return ("other", "package")
    }
}
