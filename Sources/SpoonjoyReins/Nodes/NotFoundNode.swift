import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    /// A link to a recipe the kitchen doesn't have: the recipe page's missing state (KitchenTableRouteErrorView), whose
    /// Back to recipes opens My Recipes (`spoonjoyBackToRecipes`, `openRoute(.recipes)`). Any other unknown link is
    /// the shell's Link Not Found page.
    func notFoundNode(_ route: AppRoute) -> ReinsNode {
        guard case .recipeDetail = route else {
            return ReinsNode("notFound", state: [
                "title": "Link Not Found",
                "message": "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.",
            ])
        }
        return ReinsNode("notFound", state: [
            "message": .string(RecipePageFailure.message(for: RecipeCatalogRepositoryError.recipeNotFound(route.stateIdentifier)).message),
        ], actions: [
            ReinsAction("backToRecipes", "Back to recipes") { [unowned self] in self.navigate(to: .recipes) },
        ])
    }
}
