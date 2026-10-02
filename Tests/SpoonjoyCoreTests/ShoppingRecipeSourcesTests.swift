import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Shopping recipe sources")
struct ShoppingRecipeSourcesTests {
    private static func item(_ id: String, _ name: String, checked: Bool = false, deleted: Bool = false, sortIndex: Int = 0) throws -> ShoppingListItem {
        let json: [String: Any] = [
            "id": id,
            "name": name,
            "quantity": 1,
            "unit": NSNull(),
            "checked": checked,
            "checkedAt": checked ? "2026-09-20T18:05:00.000Z" : NSNull(),
            "deletedAt": deleted ? "2026-09-20T18:06:00.000Z" : NSNull(),
            "categoryKey": "from-recipe",
            "iconKey": NSNull(),
            "sortIndex": sortIndex,
            "updatedAt": "2026-09-20T18:00:00.000Z"
        ]
        return try JSONDecoder().decode(ShoppingListItem.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private static func recipes() throws -> [Recipe] {
        try RecipeFixtureCatalog.decodeFromBundle().recipes
    }

    @Test("names match regardless of case, accents, punctuation, spacing and simple plurals")
    func normalization() {
        #expect(ShoppingRecipeSources.normalizedName("  Lemons ") == "lemon")
        #expect(ShoppingRecipeSources.normalizedName("Crème Fraîche") == "creme fraiche")
        #expect(ShoppingRecipeSources.normalizedName("Parmigiano-Reggiano, grated") == "parmigiano reggiano grated")
        #expect(ShoppingRecipeSources.normalizedName("cherry   tomatoes") == "cherry tomato")
        #expect(ShoppingRecipeSources.normalizedName("berries") == "berry")
        #expect(ShoppingRecipeSources.normalizedName("glass") == "glass")
        #expect(ShoppingRecipeSources.normalizedName("gas") == "gas")
        #expect(ShoppingRecipeSources.normalizedName("!!") == "")
    }

    @Test("finds the recipes the list's items came from, most items first")
    func findsSources() throws {
        let items = [
            try Self.item("a", "lemons"),
            try Self.item("b", "Spaghetti", sortIndex: 1),
            try Self.item("c", "parmesan", checked: true, sortIndex: 2),
            try Self.item("d", "tomatoes", sortIndex: 3),
            try Self.item("e", "paper towels", sortIndex: 4),
            try Self.item("f", "garlic", deleted: true, sortIndex: 5)
        ]
        let sources = ShoppingRecipeSources.sources(for: items, recipes: try Self.recipes())
        #expect(sources.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_toast"])

        let pasta = sources[0]
        #expect(pasta.title == "Lemon Pantry Pasta")
        #expect(pasta.matchedItemIDs == ["a", "b", "c"])
        #expect(pasta.remainingItemIDs == ["a", "b"])
        #expect(pasta.ingredientCount == 6)
        #expect(pasta.summary == "2 to buy · 1 in the basket")

        let toast = sources[1]
        #expect(toast.matchedItemIDs == ["d"])
        #expect(toast.summary == "1 to buy")
    }

    @Test("a recipe whose items are all in the basket says so")
    func allInBasket() throws {
        let sources = ShoppingRecipeSources.sources(for: [try Self.item("c", "parmesan", checked: true)], recipes: try Self.recipes())
        #expect(sources.map(\.id) == ["recipe_lemon_pantry_pasta"])
        #expect(sources[0].summary == "All in the basket")
    }

    @Test("ties keep recipes in title order, and nothing matches when the list has nothing from a recipe")
    func tiesAndEmpty() throws {
        let tie = ShoppingRecipeSources.sources(for: [try Self.item("t", "tomato"), try Self.item("l", "lemon")], recipes: try Self.recipes())
        #expect(tie.map(\.title) == ["Lemon Pantry Pasta", "Tomato Toast"])
        #expect(ShoppingRecipeSources.sources(for: [try Self.item("x", "paper towels")], recipes: try Self.recipes()).isEmpty)
        #expect(ShoppingRecipeSources.sources(for: [], recipes: try Self.recipes()).isEmpty)
    }

    @Test("an item can belong to more than one recipe")
    func sharedItem() throws {
        let recipes = try Self.recipes()
        let sources = ShoppingRecipeSources.sources(for: [try Self.item("s", "kosher salt")], recipes: recipes)
        #expect(sources.map(\.id) == ["recipe_lemon_pantry_pasta"])
        #expect(ShoppingRecipeSources.recipeTitles(forItemID: "s", in: sources) == ["Lemon Pantry Pasta"])
        #expect(ShoppingRecipeSources.recipeTitles(forItemID: "missing", in: sources).isEmpty)
    }
}
