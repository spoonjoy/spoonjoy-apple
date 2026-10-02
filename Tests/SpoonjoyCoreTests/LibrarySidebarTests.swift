import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Library sidebar")
struct LibrarySidebarTests {
    private static func cookbooks() throws -> [Cookbook] {
        let fixture = try CookbookFixtureCatalog.decodeFromBundle().cookbooks
        var borrowed = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture[0])) as? [String: Any])
        borrowed["id"] = "cookbook_borrowed"
        borrowed["title"] = "Someone Else's Book"
        borrowed["chef"] = ["id": "chef_other", "username": "other"]
        let other = try JSONDecoder().decode(Cookbook.self, from: JSONSerialization.data(withJSONObject: borrowed))
        return [fixture[0], other, fixture[1]]
    }

    @Test("lists the current chef's cookbooks in server order, like a table of contents")
    func listsOwnedCookbooks() throws {
        let entries = LibrarySidebar.cookbookEntries(cookbooks: try Self.cookbooks(), currentChefID: "chef_ari")
        #expect(entries.map(\.id) == ["cookbook_weeknights", "cookbook_no_covers"])
        #expect(entries.map(\.title) == ["Weeknights", "Inbox"])
        #expect(entries.map(\.recipeCountLabel) == ["2 recipes", "Empty"])
    }

    @Test("a signed-out kitchen lists no cookbooks")
    func signedOutListsNothing() throws {
        #expect(LibrarySidebar.cookbookEntries(cookbooks: try Self.cookbooks(), currentChefID: nil).isEmpty)
    }

    @Test("recipe counts read naturally")
    func recipeCountLabels() {
        #expect(LibrarySidebarCookbookEntry(id: "a", title: "A", recipeCount: 0).recipeCountLabel == "Empty")
        #expect(LibrarySidebarCookbookEntry(id: "a", title: "A", recipeCount: 1).recipeCountLabel == "1 recipe")
        #expect(LibrarySidebarCookbookEntry(id: "a", title: "A", recipeCount: 12).recipeCountLabel == "12 recipes")
    }

    @Test("an open cookbook from the table of contents is selected in the sidebar")
    func selectsOpenCookbook() {
        let entries = [LibrarySidebarCookbookEntry(id: "cookbook_weeknights", title: "Weeknights", recipeCount: 2)]
        #expect(LibrarySidebar.selection(route: .cookbookDetail(id: "cookbook_weeknights"), sidebarSection: .cookbooks, cookbookEntries: entries) == .cookbook(id: "cookbook_weeknights"))
    }

    @Test("any other page selects its section")
    func selectsSection() {
        let entries = [LibrarySidebarCookbookEntry(id: "cookbook_weeknights", title: "Weeknights", recipeCount: 2)]
        #expect(LibrarySidebar.selection(route: .cookbookDetail(id: "cookbook_borrowed"), sidebarSection: .cookbooks, cookbookEntries: entries) == .section(.cookbooks))
        #expect(LibrarySidebar.selection(route: .kitchen, sidebarSection: .kitchen, cookbookEntries: entries) == .section(.kitchen))
        #expect(LibrarySidebar.selection(route: .recipeDetail(id: "pasta", presentation: .detail), sidebarSection: .recipes, cookbookEntries: entries) == .section(.recipes))
    }
}
