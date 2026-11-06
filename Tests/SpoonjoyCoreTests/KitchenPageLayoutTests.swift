import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Kitchen page layout: the hero, Cooking now and the index never name a recipe twice")
struct KitchenPageLayoutTests {
    private let pasta = CookingNowTests.recipe("pasta", title: "Pasta", cover: nil)
    private let soup = CookingNowTests.recipe("soup", title: "Soup", cover: nil)
    private let bread = CookingNowTests.recipe("bread", title: "Bread", cover: nil)

    private func cook(_ recipeID: String, at updatedAt: String) throws -> CookModeProgress {
        try CookingNowTests.progress(recipeID: recipeID, steps: ["\(recipeID)-1", "\(recipeID)-2"], active: 1, ingredients: [], checked: [], updatedAt: updatedAt)
    }

    @Test("the cook on the counter leads the hero, and Cooking now and the index leave it out")
    func counterCookLeads() throws {
        let progress = ["soup": try cook("soup", at: "2026-10-25T09:00:00Z"), "bread": try cook("bread", at: "2026-10-25T08:00:00Z")]
        let entries = [
            CookingNowTests.entry("soup", stepIndex: 1, stepCount: 2, touched: 0),
            CookingNowTests.entry("bread", stepIndex: 1, stepCount: 2, touched: -60),
        ]
        let layout = KitchenPageLayout(recipes: [pasta, soup, bread], leadObject: .recipe(id: "pasta", title: "Pasta"), cookProgress: { progress[$0] }, cookingNow: entries)

        #expect(layout.counterCook?.recipeID == "soup")
        #expect(layout.leadRecipe?.id == "soup")
        #expect(layout.cookingNow.map(\.recipeID) == ["bread"])
        #expect(layout.indexedRecipes.map(\.id) == ["pasta", "bread"])
    }

    @Test("with nothing cooking the kitchen's lead recipe leads, and a lead the kitchen lacks leaves the index whole")
    func kitchenLeadAndMissingLead() {
        let led = KitchenPageLayout(recipes: [pasta, soup], leadObject: .recipe(id: "pasta", title: "Pasta"), cookProgress: { _ in nil }, cookingNow: [])
        #expect(led.counterCook == nil)
        #expect(led.leadRecipe?.id == "pasta")
        #expect(led.indexedRecipes.map(\.id) == ["soup"])
        #expect(led.cookingNow.isEmpty)

        let missing = KitchenPageLayout(recipes: [soup], leadObject: .recipe(id: "gone", title: "Gone"), cookProgress: { _ in nil }, cookingNow: [])
        #expect(missing.leadRecipe == nil)
        #expect(missing.indexedRecipes.map(\.id) == ["soup"])
    }

    @Test("the board merges and shows the kitchen's covers, and the switcher leads with the newest row")
    func boardAndSwitcher() throws {
        let cover = URL(string: "https://spoonjoy.app/covers/soup.jpg")!
        let local = [
            CookingNowTests.entry("soup", stepIndex: 1, stepCount: 2, touched: 0, cover: URL(string: "https://spoonjoy.app/stand-in.jpg")),
            CookingNowTests.entry("bread", stepIndex: 1, stepCount: 2, touched: -60),
        ]
        let board = CookingNowBoard.board(
            server: [],
            serverFetchedAt: nil,
            local: local,
            recipes: [CookingNowTests.recipe("soup", title: "Soup", cover: cover)],
            now: CookingNowTests.now
        )
        #expect(board.map(\.recipeID) == ["soup", "bread"])
        #expect(board.first?.coverURL == cover)
        #expect(CookingNowBoard.switcherLead(board)?.recipeID == "soup")
        #expect(CookingNowBoard.switcherLead([]) == nil)
    }
}
