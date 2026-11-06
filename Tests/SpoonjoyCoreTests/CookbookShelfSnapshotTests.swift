import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cookbook shelf snapshot: the saved shelf and pages the app and Ouro Reins open on")
struct CookbookShelfSnapshotTests {
    @Test("the source is live once synced and the saved copy otherwise")
    func source() throws {
        let cookbooks = try CookbookFixtureCatalog.decodeFromBundle().cookbooks
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        #expect(CookbookShelfSnapshot.source(display: .synced, cookbooks: cookbooks, now: now) == .live(requestID: "native-shell", validatedAt: now))
        let newest = try #require(cookbooks.map(\.updatedAt).max())
        #expect(CookbookShelfSnapshot.source(display: .offline, cookbooks: cookbooks, now: now) == .cache(serverRevision: .updatedAt(newest), lastValidatedAt: .distantPast))
        #expect(CookbookShelfSnapshot.source(display: .offline, cookbooks: [], now: now) == .cache(serverRevision: nil, lastValidatedAt: .distantPast))
    }

    @Test("the shelf lists every cookbook, and each page opens on its saved copy with the recipes it lacks")
    func shelfAndPages() throws {
        let cookbooks = try CookbookFixtureCatalog.decodeFromBundle().cookbooks
        let cookbook = try #require(cookbooks.first)
        let saved = try #require(cookbook.recipes.first)
        let extra = CookingNowTests.recipe("recipe_extra", title: "Extra", cover: nil)
        let inBook = CookingNowTests.recipe(saved.id, title: saved.title, cover: nil)
        let source = CookbookSurfaceDataSource.cache(serverRevision: nil, lastValidatedAt: .distantPast)

        let page = CookbookShelfSnapshot.page(cookbooks: cookbooks, source: source)
        #expect(page.rows.map(\.id) == cookbooks.map(\.id))
        #expect(page.limit == max(20, cookbooks.count))
        #expect(!page.hasMore)

        let repository = CookbookShelfSnapshot.repository(cookbooks: cookbooks, recipes: [inBook, extra], source: source)
        let detail = try #require(repository.cachedCookbookDetail(id: cookbook.id))
        #expect(detail.availableRecipes.map(\.id) == ["recipe_extra"])
        #expect(CookbookShelfSnapshot.availableRecipes(for: cookbook, in: [inBook]).isEmpty)
    }

    @Test("the search field comes with a second recipe, and no match says what was searched")
    func search() {
        #expect(!CookbookRecipeSearch.offersSearchField(recipeCount: 1))
        #expect(CookbookRecipeSearch.offersSearchField(recipeCount: 2))
        #expect(CookbookRecipeSearch.noMatchTitle(query: "  kale ") == "No recipes match \u{201C}kale\u{201D}")
    }
}

@Suite("Recipe page failure: missing and failing recipes say so")
struct RecipePageFailureTests {
    @Test("a recipe the catalog lacks is missing; any other failure is a load failure")
    func messages() {
        #expect(RecipePageFailure.message(for: RecipeCatalogRepositoryError.recipeNotFound("recipe_gone")) == (RecipePageFailure.notFound, true))
        #expect(RecipePageFailure.message(for: CocoaError(.fileNoSuchFile)) == (RecipePageFailure.unavailable, false))
        #expect(RecipePageFailure.notFound == "We couldn't find this recipe.")
        #expect(RecipePageFailure.unavailable == "We couldn't load this recipe.")
    }
}
