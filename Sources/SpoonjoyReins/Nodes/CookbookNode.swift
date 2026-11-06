import OuroReins
import SpoonjoyCore

struct SearchQueryInput: ReinsInput {
    let query: String
}

extension SpoonjoyReinsShell {
    /// A cookbook page (CookbookDetailRouteView, then CookbookDetailView): the saved copy, its numbered recipes, the
    /// "Search this cookbook" field once there is more than one, and the no-match line.
    func cookbookNode(_ id: String) -> ReinsNode {
        let viewModel = cookbookSurfaceViewModel
        guard viewModel.showCachedDetail(id: id), let detail = viewModel.detail else {
            return ReinsNode("cookbook", state: ["id": .string(id), "error": "We couldn't load this cookbook."])
        }
        let offersSearch = CookbookRecipeSearch.offersSearchField(recipeCount: detail.recipes.count)
        let query = offersSearch ? page.cookbookQuery : ""
        let matching = Set(CookbookRecipeSearch.filter(detail.recipes, query: query) { $0.title }.map(\.id))
        var state: [String: ReinsValue] = [
            "id": .string(detail.id),
            "title": .string(detail.title),
            "recipeCount": .string(detail.recipeCountLabel),
            "recipes": .array(detail.recipes.enumerated().compactMap { index, recipe in
                matching.contains(recipe.id) ? ["ordinal": .number(Double(index + 1)), "id": .string(recipe.id), "title": .string(recipe.title)] : nil
            }),
            "searchField": .bool(offersSearch),
            "query": .string(query),
        ]
        if matching.isEmpty, !detail.recipes.isEmpty {
            state["noMatch"] = [
                "title": .string(CookbookRecipeSearch.noMatchTitle(query: query)),
                "help": .string(SearchSurfaceEmptyState.noMatchHelp),
            ]
        }
        var actions: [ReinsAction] = []
        if offersSearch {
            actions.append(ReinsAction("search", "Search this cookbook", input: SearchQueryInput.self) { [unowned self] in
                self.page.cookbookQuery = $0.query
            })
        }
        let visible = detail.recipes.filter { matching.contains($0.id) }
        if !visible.isEmpty {
            actions.append(ReinsAction("openRecipe", "Open a recipe", input: RecipeID.self) { [unowned self] input in
                guard let row = visible.first(where: { $0.id == input.id }) else { return }
                self.navigate(to: row.openRoute)
            }.narrowed(.object(properties: ["id": .oneOf(visible.map(\.id))], required: ["id"])))
        }
        return ReinsNode("cookbook", state: .object(state), actions: actions)
    }
}
