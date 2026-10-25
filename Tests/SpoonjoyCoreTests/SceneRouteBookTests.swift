import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Each window reopens on its own page")
struct SceneRouteBookTests {
    static let start = Date(timeIntervalSince1970: 1_793_000_000)

    @Test("a window value carries a route and reads it back")
    func windowRoute() {
        let cook = WindowRoute(.recipeDetail(id: "recipe_pasta", presentation: .cook))
        #expect(cook.stateIdentifier == "recipe-cook:recipe_pasta")
        #expect(cook.route == .recipeDetail(id: "recipe_pasta", presentation: .cook))
        let decoded = try? JSONDecoder().decode(WindowRoute.self, from: JSONEncoder().encode(cook))
        #expect(decoded == cook)
    }

    @Test("two windows keep separate pages, and closing a window forgets its page")
    func twoWindows() {
        var book = SceneRouteBook()
        book.record(.recipeDetail(id: "recipe_pasta", presentation: .cook), scene: "left", at: Self.start)
        book.record(.recipeDetail(id: "recipe_tart", presentation: .detail), scene: "right", at: Self.start)
        #expect(book.route(forScene: "left") == .recipeDetail(id: "recipe_pasta", presentation: .cook))
        #expect(book.route(forScene: "right") == .recipeDetail(id: "recipe_tart", presentation: .detail))
        #expect(book.route(forScene: "missing") == nil)
        book.record(.kitchen, scene: "left", at: Self.start.addingTimeInterval(5))
        #expect(book.route(forScene: "left") == .kitchen)
        book.forget(scenes: ["left", "never-seen"])
        #expect(book.route(forScene: "left") == nil)
        #expect(book.pages.keys.sorted() == ["right"])
    }

    @Test("past capacity the oldest page goes first, oldest by time then by name")
    func capacity() {
        var book = SceneRouteBook()
        (0..<SceneRouteBook.capacity).forEach { index in
            book.record(.kitchen, scene: String(format: "scene-%02d", index), at: Self.start.addingTimeInterval(TimeInterval(index / 2)))
        }
        #expect(book.pages.count == SceneRouteBook.capacity)
        book.record(.recipes, scene: "newest", at: Self.start.addingTimeInterval(100))
        #expect(book.pages.count == SceneRouteBook.capacity)
        #expect(book.pages["scene-00"] == nil)
        #expect(book.pages["scene-01"] != nil)
        #expect(book.route(forScene: "newest") == .recipes)
    }

    @Test("the window's own page wins, then its opening value, and only a lone window takes the app's last page")
    func restorationOrder() {
        let own = AppRoute.recipeDetail(id: "own", presentation: .cook)
        let value = AppRoute.recipeDetail(id: "value", presentation: .detail)
        let last = AppRoute.recipes
        #expect(SceneRestoration.route(scenePage: own, windowValue: value, appLastRoute: last, isOnlyWindow: true) == own)
        #expect(SceneRestoration.route(scenePage: nil, windowValue: value, appLastRoute: last, isOnlyWindow: false) == value)
        #expect(SceneRestoration.route(scenePage: nil, windowValue: nil, appLastRoute: last, isOnlyWindow: true) == last)
        #expect(SceneRestoration.route(scenePage: nil, windowValue: nil, appLastRoute: last, isOnlyWindow: false) == nil)
    }

    @Test("pages to read or cook are remembered; searches, editors, capture and settings are not")
    func remembered() {
        let remembered: [AppRoute] = [
            .kitchen, .recipes, .savedRecipes, .everyoneRecipes, .recipeDetail(id: "r", presentation: .cook),
            .recipeDetail(id: "r", presentation: .detail), .cookbooks, .cookbookDetail(id: "c"), .chefs,
            .profile(identifier: "ari"), .shoppingList
        ]
        let forgotten: [AppRoute] = [
            .recipeEditor(id: nil), .recipeEditor(id: "r"), .recipeCoverControls(id: "r"),
            .profileGraph(identifier: "ari", direction: .fellowChefs, page: 1),
            .search(query: "basil", scope: .all), .capture, .settings, .unknownLink
        ]
        #expect(remembered.allSatisfy(SceneRestoration.remembers))
        #expect(!forgotten.contains(where: SceneRestoration.remembers))
    }

    @Test("the book survives the app being killed, and an unreadable file reads as empty")
    func store() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("scene-routes-\(UUID().uuidString)", isDirectory: true)
        let store = SceneRouteBookStore(directory: directory)
        #expect(store.load() == SceneRouteBook())
        store.update { $0.record(.recipeDetail(id: "recipe_pasta", presentation: .cook), scene: "left", at: Self.start) }
        store.update { $0.record(.shoppingList, scene: "right", at: Self.start) }
        let reopened = SceneRouteBookStore(directory: directory).load()
        #expect(reopened.route(forScene: "left") == .recipeDetail(id: "recipe_pasta", presentation: .cook))
        #expect(reopened.route(forScene: "right") == .shoppingList)
        try Data("not json".utf8).write(to: directory.appendingPathComponent(SceneRouteBookStore.fileName))
        #expect(store.load() == SceneRouteBook())
    }
}
