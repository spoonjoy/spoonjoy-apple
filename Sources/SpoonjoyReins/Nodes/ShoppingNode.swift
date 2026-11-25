import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// The Shopping List. Its recipe entry and its menu's Units are modelled: with no recipes it offers Add a recipe
    /// (`ShoppingListView.createRecipeButton`), and otherwise Add from recipe, which opens Search. The items show
    /// their amounts in the picked units (`ShoppingReceiptRow`).
    var shoppingNode: ReinsNode {
        let hasRecipes = !content.recipes.isEmpty
        let system = unitSystem
        return ReinsNode("shopping", state: [
            "recipeAction": hasRecipes ? "Add from recipe" : "Add a recipe",
            "units": unitsState,
            "items": .array((content.shoppingList?.items ?? []).filter { $0.deletedAt == nil }.map { item in
                ["name": .string(item.name), "amount": .string(item.displayQuantity(in: system))]
            }),
            "x-unmodelled": "the list's aisles, filters and composer",
        ], actions: [
            hasRecipes
                ? ReinsAction("addFromRecipe", "Add from recipe") { [unowned self] in self.navigate(to: .search(query: "", scope: .recipes)) }
                : ReinsAction("addRecipe", "Add a recipe") { [unowned self] in self.presentAddRecipe() },
            pickUnitsAction("pickUnits", "Pick the units the list's amounts are written in, from its menu"),
        ])
    }
}
