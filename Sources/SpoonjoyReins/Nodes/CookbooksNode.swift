import Foundation
import OuroReins
import SpoonjoyCore

struct CookbookIDInput: ReinsInput {
    let id: String
}

extension SpoonjoyReinsShell {
    /// The cookbook view model PlatformNavigationView builds, over the saved shelf (`CookbookShelfSnapshot`): a
    /// headless launch has no live cookbook endpoint, so each page opens on its saved copy.
    var cookbookSurfaceViewModel: CookbookSurfaceViewModel {
        let source = CookbookShelfSnapshot.source(display: content.offlineIndicatorState.display, cookbooks: content.cookbooks, now: fixtures.now())
        let currentChefID = content.trustedAccountID
        let viewModel = CookbookSurfaceViewModel(
            repository: CookbookShelfSnapshot.repository(cookbooks: content.cookbooks, recipes: content.recipes, source: source),
            context: CookbookSurfaceContext(
                currentChefID: currentChefID,
                currentChef: content.recipes.first?.chef ?? content.cookbooks.first?.chef ?? currentChefID.map { ChefSummary(id: $0, username: "Spoonjoy") }
            ),
            queuedMutations: content.queuedMutations,
            conflicts: content.syncConflicts,
            connectivity: content.offlineIndicatorState.display == .offline ? .offline : .online,
            now: fixtures.now,
            timestamp: { [now = fixtures.now] in ISO8601DateFormatter().string(from: now()) }
        )
        viewModel.apply(page: CookbookShelfSnapshot.page(cookbooks: content.cookbooks, source: source))
        return viewModel
    }

    /// The Cookbooks shelf (CookbooksView): each row opens its cookbook page.
    var cookbooksNode: ReinsNode {
        let list = cookbookSurfaceViewModel.list
        let ids = list.rows.map(\.id)
        return ReinsNode("cookbooks", state: [
            "rows": .array(list.rows.map { ["id": .string($0.id), "title": .string($0.title), "recipes": .string($0.recipeCountLabel)] }),
            "empty": list.emptyState.map { .string(String(describing: $0)) } ?? .null,
        ], actions: ids.isEmpty ? [] : [
            ReinsAction("openCookbook", "Open a cookbook", input: CookbookIDInput.self) { [unowned self] in
                self.page.cookbookQuery = ""
                self.openCookbook($0.id)
            }.narrowed(.object(properties: ["id": .oneOf(ids)], required: ["id"])),
        ])
    }
}
