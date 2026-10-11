import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Kitchen, cookbook and search polish")
struct KitchenCookbookSearchPolishTests {
    @Test("the recipe index counts every saved recipe, matching the masthead")
    func recipeIndexCount() {
        #expect(KitchenRecipeIndexSummary(recipeCount: 4).subtitle == "4 saved recipes")
        #expect(KitchenRecipeIndexSummary(recipeCount: 1).subtitle == "1 saved recipe")
        #expect(KitchenRecipeIndexSummary(recipeCount: -2).subtitle == "0 saved recipes")
    }

    @Test("cookbook search needs every word and ignores case and accents")
    func cookbookSearch() {
        let titles = ["Miso Glazed Salmon", "Saffron Risotto", "Crème Brûlée"]
        #expect(CookbookRecipeSearch.filter(titles, query: "  ", text: { $0 }) == titles)
        #expect(CookbookRecipeSearch.filter(titles, query: "miso sal", text: { $0 }) == ["Miso Glazed Salmon"])
        #expect(CookbookRecipeSearch.filter(titles, query: "creme brulee", text: { $0 }) == ["Crème Brûlée"])
        #expect(CookbookRecipeSearch.filter(titles, query: "miso risotto", text: { $0 }).isEmpty)
    }

    @Test("search rows show a snippet only when it adds something")
    func snippets() {
        #expect(row(snippet: "...dissolve white miso in warm water...").snippetText == "dissolve white miso in warm water")
        #expect(row(snippet: "  fresh \n basil  ").snippetText == "fresh basil")
        #expect(row(snippet: nil).snippetText == nil)
        #expect(row(snippet: " ... ").snippetText == nil)
        #expect(row(snippet: "miso glazed salmon").snippetText == nil)
        #expect(row(snippet: "recipe by ari").snippetText == nil)
    }

    @Test("search rows fall back to the cover the app already holds")
    func imageFallback() {
        let serverImage = URL(string: "https://spoonjoy.app/server.jpg")!
        let recipeCover = URL(string: "https://spoonjoy.app/recipe.jpg")!
        let bookCover = URL(string: "https://spoonjoy.app/book.jpg")!
        let recipeCovers = ["r1": recipeCover]
        let cookbookCovers = ["r1": bookCover]

        #expect(row(imageURL: serverImage).imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers) == serverImage)
        #expect(row().imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers) == recipeCover)
        #expect(row(type: .cookbook).imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers) == bookCover)
        #expect(row(type: .chef).imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers) == nil)
        #expect(row(type: .shoppingListItem).imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers) == nil)
    }

    @Test("scope labels are short enough for the iPhone scope bar")
    func scopeLabels() {
        #expect(SearchScope.allCases.map(\.compactTitle) == ["All", "Recipes", "Books", "Chefs", "Shopping"])
        #expect(SearchScope.allCases.allSatisfy { $0.compactTitle.count <= 8 })
    }

    private func row(
        type: SearchSurfaceResultType = .recipe,
        snippet: String? = "x",
        imageURL: URL? = nil
    ) -> SearchSurfaceRow {
        SearchSurfaceRow(result: SearchSurfaceResult(
            type: type,
            id: "r1",
            ownerID: nil,
            ownerUsername: "ari",
            title: "Miso Glazed Salmon",
            subtitle: "Recipe by ari",
            snippet: snippet,
            href: "/recipes/r1",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/r1")!,
            imageURL: imageURL,
            score: 0,
            metadata: [:]
        ))
    }
}
