import Foundation

/// A recipe that items on the shopping list came from, shown beside the list on a wide screen.
public struct ShoppingRecipeSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let coverImageURL: URL?
    /// Every list item that matches one of the recipe's ingredients, in list order.
    public let matchedItemIDs: [String]
    /// The matched items still to buy.
    public let remainingItemIDs: [String]
    /// The number of distinct ingredients the recipe calls for.
    public let ingredientCount: Int

    public var summary: String {
        let inBasket = matchedItemIDs.count - remainingItemIDs.count
        if remainingItemIDs.isEmpty {
            return "All in the basket"
        }
        if inBasket == 0 {
            return "\(remainingItemIDs.count) to buy"
        }
        return "\(remainingItemIDs.count) to buy · \(inBasket) in the basket"
    }
}

/// Works out which recipes the shopping list's items came from.
///
/// Shopping items do not record the recipe that added them, but an item added from a recipe carries the
/// ingredient's name. Matching names after light normalization (case, accents, punctuation, spacing and simple
/// plurals) finds those recipes without guessing: an item matches only an ingredient with the same name.
public enum ShoppingRecipeSources {
    public static func sources(for items: [ShoppingListItem], recipes: [Recipe]) -> [ShoppingRecipeSource] {
        let listItems = items
            .filter { $0.deletedAt == nil }
            .sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        let sources = recipes.compactMap { recipe -> ShoppingRecipeSource? in
            let ingredientNames = Set(recipe.steps.flatMap(\.ingredients).map { normalizedName($0.name) })
            let matched = listItems.filter { ingredientNames.contains(normalizedName($0.name)) }
            guard !matched.isEmpty else {
                return nil
            }
            return ShoppingRecipeSource(
                id: recipe.id,
                title: recipe.title,
                coverImageURL: recipe.displayCoverImageURL,
                matchedItemIDs: matched.map(\.id),
                remainingItemIDs: matched.filter { !$0.isEffectivelyChecked }.map(\.id),
                ingredientCount: ingredientNames.count
            )
        }
        return sources.sorted { left, right in
            if left.matchedItemIDs.count != right.matchedItemIDs.count {
                return left.matchedItemIDs.count > right.matchedItemIDs.count
            }
            return left.title.localizedStandardCompare(right.title) == .orderedAscending
        }
    }

    /// The titles of the recipes an item came from.
    public static func recipeTitles(forItemID itemID: String, in sources: [ShoppingRecipeSource]) -> [String] {
        sources.filter { $0.matchedItemIDs.contains(itemID) }.map(\.title)
    }

    public static func normalizedName(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = folded
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .split(separator: " ")
            .map { singular(String($0)) }
        return words.joined(separator: " ")
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 {
            return String(word.dropLast(3)) + "y"
        }
        if word.hasSuffix("oes"), word.count > 4 {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 {
            return String(word.dropLast())
        }
        return word
    }
}
