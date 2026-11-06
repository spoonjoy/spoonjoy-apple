import Foundation

/// What the Kitchen page shows where: the cook on the counter, the recipe the hero leads with, the Cooking now rows and
/// the recipe index. `KitchenView` and Ouro Reins both read it, so the page never names the same recipe twice in two
/// places.
public struct KitchenPageLayout: Equatable, Sendable {
    /// The unfinished cook touched last, which the hero resumes.
    public let counterCook: KitchenCounterCook?
    /// The cook on the counter's recipe, else the kitchen's own lead recipe.
    public let leadRecipe: Recipe?
    /// The recipes on the stove less the one the hero already leads with.
    public let cookingNow: [CookingNowEntry]
    /// Every recipe less the one the hero leads with.
    public let indexedRecipes: [Recipe]

    public init(
        recipes: [Recipe],
        leadObject: KitchenLeadObject,
        cookProgress: (String) -> CookModeProgress?,
        cookingNow entries: [CookingNowEntry]
    ) {
        let counterCook = KitchenCounterCook.resolve(recipeIDs: recipes.map(\.id), progress: cookProgress)
        let leadRecipe: Recipe?
        if let counterCook, let cooking = recipes.first(where: { $0.id == counterCook.recipeID }) {
            leadRecipe = cooking
        } else {
            let leadID: String
            switch leadObject {
            case .recipe(let id, _):
                leadID = id
            }
            leadRecipe = recipes.first { $0.id == leadID }
        }
        self.counterCook = counterCook
        self.leadRecipe = leadRecipe
        cookingNow = entries.filter { $0.recipeID != counterCook?.recipeID }
        indexedRecipes = leadRecipe.map { lead in recipes.filter { $0.id != lead.id } } ?? recipes
    }
}

extension CookingNowBoard {
    /// The rows the Kitchen and the tab bar show: the server's list merged with this device's, each with the
    /// kitchen's own cover. `CookingNowCenter` publishes it; Ouro Reins reads it with no server list.
    public static func board(
        server: [CookingNowEntry],
        serverFetchedAt: Date?,
        local: [CookingNowEntry],
        recipes: [Recipe],
        now: Date
    ) -> [CookingNowEntry] {
        showingKitchenCovers(merge(server: server, serverFetchedAt: serverFetchedAt, local: local, now: now), recipes: recipes)
    }

    /// The tab bar switcher's leading row: the newest recipe on the stove, one tap from its step.
    public static func switcherLead(_ entries: [CookingNowEntry]) -> CookingNowEntry? {
        entries.first
    }
}
