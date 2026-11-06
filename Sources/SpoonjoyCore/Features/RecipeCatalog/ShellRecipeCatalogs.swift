import Foundation

extension NativeShellContentState {
    /// Everyone's Recipes: the server's public catalog, and the catalog this device last saw when the server can't
    /// be reached.
    public func everyoneRecipeCatalogRepository(live: any RecipeCatalogRepository) -> any RecipeCatalogRepository {
        let catalog = recipeCatalog
        let snapshotRepository = SnapshotRecipeCatalogRepository(
            page: catalog,
            details: recipes.map { RecipeCatalogDetailResult(recipe: $0, source: catalog.source) }
        )
        return FallbackRecipeCatalogRepository(primary: live, fallback: snapshotRepository)
    }

    /// My Recipes or Saved Recipes: the page this device holds, with the loaded recipes it lists.
    public func personalRecipeCatalogRepository(page: RecipeCatalogPage) -> any RecipeCatalogRepository {
        let listedIDs = Set(page.rows.map(\.id))
        return SnapshotRecipeCatalogRepository(
            page: page,
            details: recipes
                .filter { listedIDs.contains($0.id) }
                .map { RecipeCatalogDetailResult(recipe: $0, source: page.source) }
        )
    }
}
