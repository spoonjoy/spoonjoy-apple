import Foundation

/// The cookbook shelf and pages as the account sync saved them: the page the shelf lists and the copy each cookbook
/// page opens on before the live copy arrives. `PlatformNavigationView` builds its cookbook view model from these;
/// Ouro Reins reads the same saved copy.
public enum CookbookShelfSnapshot {
    /// Live once the app has synced; otherwise the saved copy, stamped with the newest cookbook's revision.
    public static func source(display: OfflineIndicatorDisplay, cookbooks: [Cookbook], now: Date) -> CookbookSurfaceDataSource {
        switch display {
        case .synced:
            .live(requestID: "native-shell", validatedAt: now)
        case .offline, .stale, .dismissed, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            .cache(serverRevision: cookbooks.map(\.updatedAt).max().map(NativeCacheServerRevision.updatedAt), lastValidatedAt: .distantPast)
        }
    }

    /// The shelf: every one of the chef's own cookbooks on one page.
    public static func page(cookbooks: [Cookbook], source: CookbookSurfaceDataSource) -> CookbookSurfacePage {
        CookbookSurfacePage(
            query: nil,
            limit: max(20, cookbooks.count),
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: cookbooks.map(CookbookSummary.init(cookbook:)),
            source: source
        )
    }

    /// The saved shelf and each saved cookbook page, with the kitchen's recipes the cookbook doesn't hold yet.
    public static func repository(cookbooks: [Cookbook], recipes: [Recipe], source: CookbookSurfaceDataSource) -> SnapshotCookbookSurfaceRepository {
        SnapshotCookbookSurfaceRepository(
            page: page(cookbooks: cookbooks, source: source),
            details: cookbooks.map { cookbook in
                CookbookSurfaceDetailResult(cookbook: cookbook, source: source, availableRecipes: availableRecipes(for: cookbook, in: recipes))
            }
        )
    }

    /// The kitchen's recipes not already in `cookbook`, for its Add a recipe picker.
    public static func availableRecipes(for cookbook: Cookbook, in recipes: [Recipe]) -> [RecipeSummary] {
        let savedRecipeIDs = Set(cookbook.recipes.map(\.id))
        return recipes.filter { !savedRecipeIDs.contains($0.id) }.map(RecipeSummary.init(recipe:))
    }
}

extension CookbookRecipeSearch {
    /// A cookbook page offers "Search this cookbook" once it holds more than one recipe.
    public static func offersSearchField(recipeCount: Int) -> Bool {
        recipeCount > 1
    }

    /// What the page says when the search matches no recipe.
    public static func noMatchTitle(query: String) -> String {
        "No recipes match \u{201C}\(query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}"
    }
}
