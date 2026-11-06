import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// The Shopping List. Only its recipe entry is modelled: with no recipes it offers Add a recipe
    /// (`ShoppingListView.createRecipeButton`), and otherwise Add from recipe, which opens Search.
    var shoppingNode: ReinsNode {
        let hasRecipes = !content.recipes.isEmpty
        return ReinsNode("shopping", state: [
            "recipeAction": hasRecipes ? "Add from recipe" : "Add a recipe",
            "x-unmodelled": "the list's items, aisles and composer",
        ], actions: [
            hasRecipes
                ? ReinsAction("addFromRecipe", "Add from recipe") { [unowned self] in self.navigate(to: .search(query: "", scope: .recipes)) }
                : ReinsAction("addRecipe", "Add a recipe") { [unowned self] in self.presentAddRecipe() },
        ])
    }
}
