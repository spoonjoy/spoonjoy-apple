import OuroReins
import SpoonjoyCore

struct RecipesScope: ReinsInput { let scope: String }

extension SpoonjoyReinsShell {
    private static let scopes: [(name: String, route: AppRoute)] = [("mine", .recipes), ("saved", .savedRecipes), ("everyone", .everyoneRecipes)]

    /// The Recipes tab: Mine, Saved and Everyone (`RecipesView` over `RecipeCatalogViewModel`), with the picker above.
    func recipesNode(_ route: AppRoute) -> ReinsNode {
        let scope = Self.scopes.first { $0.route == route }?.name ?? "mine"
        let state = page.recipeCatalogs[route.stateIdentifier] ?? recipeCatalogViewModel(for: route).state
        let ids = state.rows.map(\.id)
        var actions = [
            ReinsAction("chooseScope", "Show my recipes, saved recipes or everyone's", input: RecipesScope.self) { [unowned self] input in
                guard let next = Self.scopes.first(where: { $0.name == input.scope })?.route else { return }
                self.navigate(to: next)
                await self.loadRecipeCatalog(next)
            }.narrowed(.object(properties: ["scope": .oneOf(Self.scopes.map(\.name))], required: ["scope"])),
        ]
        if !ids.isEmpty {
            actions.append(ReinsAction("openRecipe", "Open a recipe", input: RecipeID.self) { [unowned self] in
                self.navigate(to: .recipeDetail(id: $0.id, presentation: .detail))
            }.narrowed(.object(properties: ["id": .oneOf(ids)], required: ["id"])))
        }
        if route == .recipes {
            actions.append(ReinsAction("addRecipe", "Add a recipe") { [unowned self] in self.presentAddRecipe() })
        }
        return ReinsNode("recipes", state: [
            "scope": .string(scope),
            "rows": .array(state.rows.map { ["id": .string($0.id), "title": .string($0.title)] }),
            "count": .string(state.resultCountLabel),
            "empty": state.emptyState.map { .string($0.title) } ?? .null,
        ], actions: actions)
    }

    /// The list's view model, as `PlatformNavigationView` builds it: the page this device holds, over the repository
    /// the list reloads from.
    func recipeCatalogViewModel(for route: AppRoute) -> RecipeCatalogViewModel {
        let page: RecipeCatalogPage
        let repository: any RecipeCatalogRepository
        switch route {
        case .everyoneRecipes:
            page = content.recipeCatalog
            let live = fixtures.catalogTransport.map { LiveRecipeCatalogRepository(transport: $0, configuration: content.configuration) }
                ?? LiveRecipeCatalogRepository(configuration: content.configuration)
            repository = content.everyoneRecipeCatalogRepository(live: live)
        case .savedRecipes:
            page = content.savedRecipesCatalog
            repository = content.personalRecipeCatalogRepository(page: page)
        default:
            page = content.myRecipesCatalog
            repository = content.personalRecipeCatalogRepository(page: page)
        }
        let viewModel = RecipeCatalogViewModel(repository: repository)
        viewModel.apply(page: page)
        return viewModel
    }

    /// `RecipesView`'s `.task` and `loadCatalog(query:)`: the list loads when it appears.
    func loadRecipeCatalog(_ route: AppRoute) async {
        let viewModel = recipeCatalogViewModel(for: route)
        try? await viewModel.load(query: viewModel.state.query, limit: viewModel.state.limit)
        page.recipeCatalogs[route.stateIdentifier] = viewModel.state
    }
}
