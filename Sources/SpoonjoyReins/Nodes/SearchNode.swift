import OuroReins
import SpoonjoyCore

struct SearchQuery: ReinsInput { let query: String }

extension SpoonjoyReinsShell {
    /// The Search tab (`SearchSurfaceView` over `SearchSurfaceViewModel`): the field, and the results by section.
    func searchNode(query: String, scope: SearchScope) -> ReinsNode {
        let state = SearchState(query: query, scope: scope)
        // The last run, while it is for this search; otherwise what this device last saw for it.
        let viewModel = page.search.flatMap { $0.state == state ? $0 : nil } ?? content.performSearch(state)
        let ids = viewModel.sections.flatMap(\.rows).map(\.id)
        var actions = [
            ReinsAction("search", "Search for recipes, cookbooks and chefs", input: SearchQuery.self) { [unowned self] in
                await self.runSearch(SearchState(query: $0.query, scope: scope))
            },
        ]
        if !ids.isEmpty {
            actions.append(ReinsAction("openResult", "Open a result", input: RecipeID.self) { [unowned self] input in
                guard let row = viewModel.sections.flatMap(\.rows).first(where: { $0.id == input.id }) else { return }
                self.navigate(to: row.openRoute)
            }.narrowed(.object(properties: ["id": .oneOf(ids)], required: ["id"])))
        }
        return ReinsNode("search", state: [
            "query": .string(viewModel.state.query),
            "scope": .string(viewModel.state.scope.rawValue),
            "sections": .array(viewModel.sections.map { section in
                [
                    "kind": .string(section.kind.rawValue),
                    "rows": .array(section.rows.map { ["id": .string($0.id), "title": .string($0.title)] }),
                ]
            }),
            "results": .array(viewModel.sections.flatMap(\.rows).map { .string($0.title) }),
            "empty": viewModel.emptyState.map { .string($0.title) } ?? .null,
            "error": viewModel.errorState.map { .string($0.title) } ?? .null,
        ], actions: actions)
    }

    /// `PlatformNavigationView.performSearch(_:)`: the route follows the field, then the search runs and its page is
    /// recorded for the next time it's offline.
    func runSearch(_ state: SearchState) async {
        let identity = content.searchSurfaceIdentity
        navigate(to: state.route)
        guard state.hasQuery else {
            page.search = content.performSearch(state)
            return
        }
        let cachedPage = content.searchSurfacePage(for: state)
        let run = await SearchSurfaceRun.run(state, in: store.searchSurfaceRepository(context: content.searchSurfaceContext))
        guard run != .cancelled, content.searchSurfaceIdentity == identity, navigation.route == state.route else {
            return
        }
        if case .page(let page) = run {
            try? store.recordSearchSurfacePage(page, expectedIdentity: identity)
        }
        page.search = content.searchSurfaceViewModel(after: run, state: state, cachedPage: cachedPage)
    }
}
