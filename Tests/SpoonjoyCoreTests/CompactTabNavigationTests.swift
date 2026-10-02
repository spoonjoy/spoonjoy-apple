import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Compact tab navigation")
struct CompactTabNavigationTests {
    private let pasta = AppRoute.recipeDetail(id: "pasta", presentation: .detail)
    private let pastaCook = AppRoute.recipeDetail(id: "pasta", presentation: .cook)

    @Test("tabs are Kitchen, Recipes, Cookbooks, Shopping and the search tab, in that order")
    func tabOrder() {
        #expect(CompactTab.allCases == [.kitchen, .recipes, .cookbooks, .shopping, .search])
    }

    @Test("every route has a place in the compact shell")
    func placements() {
        #expect(CompactTabNavigation.placement(for: .kitchen) == .root(.kitchen))
        #expect(CompactTabNavigation.placement(for: .recipes) == .root(.recipes))
        #expect(CompactTabNavigation.placement(for: .savedRecipes) == .root(.recipes))
        #expect(CompactTabNavigation.placement(for: .cookbooks) == .root(.cookbooks))
        #expect(CompactTabNavigation.placement(for: .shoppingList) == .root(.shopping))
        #expect(CompactTabNavigation.placement(for: .search(query: "basil", scope: .recipes)) == .root(.search))
        #expect(CompactTabNavigation.placement(for: pastaCook) == .fullScreen)
        for route: AppRoute in [
            pasta,
            .recipeEditor(id: nil),
            .recipeEditor(id: "pasta"),
            .recipeCoverControls(id: "pasta"),
            .cookbookDetail(id: "weeknights"),
            .profile(identifier: "ari"),
            .profileGraph(identifier: "ari", direction: .fellowChefs, page: 1)
        ] {
            #expect(CompactTabNavigation.placement(for: route) == .pushedOnSelectedTab)
        }
        for route: AppRoute in [.chefs, .capture, .settings, .unknownLink] {
            #expect(CompactTabNavigation.placement(for: route) == .pushed(onto: .kitchen))
        }
    }

    @Test("a fresh shell starts on the Kitchen root, or on the route it launches into")
    func initialState() {
        let fresh = CompactTabNavigation()
        #expect(fresh.selectedTab == .kitchen)
        #expect(fresh.route == .kitchen)
        #expect(fresh.recipesRoot == .recipes)
        #expect(fresh.searchRoot == .search(query: "", scope: .all))
        #expect(fresh.fullScreenRoute == nil)
        for tab in CompactTab.allCases {
            #expect(fresh.path(for: tab).isEmpty)
        }
        #expect(fresh.root(for: .kitchen) == .kitchen)
        #expect(fresh.root(for: .recipes) == .recipes)
        #expect(fresh.root(for: .cookbooks) == .cookbooks)
        #expect(fresh.root(for: .shopping) == .shoppingList)
        #expect(fresh.root(for: .search) == .search(query: "", scope: .all))

        let deepLinked = CompactTabNavigation(route: .cookbookDetail(id: "weeknights"))
        #expect(deepLinked.selectedTab == .kitchen)
        #expect(deepLinked.path(for: .kitchen) == [.cookbookDetail(id: "weeknights")])
        #expect(deepLinked.route == .cookbookDetail(id: "weeknights"))
    }

    @Test("root routes select their tab and pop it to the root")
    func rootRoutes() {
        var tabs = CompactTabNavigation()
        tabs.apply(.cookbooks)
        tabs.apply(.cookbookDetail(id: "weeknights"))
        #expect(tabs.path(for: .cookbooks) == [.cookbookDetail(id: "weeknights")])

        tabs.apply(.cookbooks)
        #expect(tabs.selectedTab == .cookbooks)
        #expect(tabs.path(for: .cookbooks).isEmpty)
        #expect(tabs.route == .cookbooks)

        tabs.apply(.savedRecipes)
        #expect(tabs.selectedTab == .recipes)
        #expect(tabs.recipesRoot == .savedRecipes)
        #expect(tabs.route == .savedRecipes)
        tabs.apply(.recipes)
        #expect(tabs.recipesRoot == .recipes)

        tabs.apply(.search(query: "basil", scope: .recipes))
        #expect(tabs.selectedTab == .search)
        #expect(tabs.searchRoot == .search(query: "basil", scope: .recipes))
        #expect(tabs.route == .search(query: "basil", scope: .recipes))

        tabs.apply(.shoppingList)
        #expect(tabs.selectedTab == .shopping)
        #expect(tabs.route == .shoppingList)
        // Other tabs keep their roots.
        #expect(tabs.root(for: .recipes) == .recipes)
        #expect(tabs.root(for: .search) == .search(query: "basil", scope: .recipes))
    }

    @Test("detail pages push onto the tab they were opened from")
    func detailPagesPushOntoSelectedTab() {
        var tabs = CompactTabNavigation()
        tabs.apply(pasta)
        #expect(tabs.selectedTab == .kitchen)
        #expect(tabs.path(for: .kitchen) == [pasta])

        tabs.apply(.search(query: "pasta", scope: .all))
        tabs.apply(pasta)
        #expect(tabs.selectedTab == .search)
        #expect(tabs.path(for: .search) == [pasta])
        tabs.apply(.profile(identifier: "ari"))
        #expect(tabs.path(for: .search) == [pasta, .profile(identifier: "ari")])
        // The Kitchen keeps its own stack.
        #expect(tabs.path(for: .kitchen) == [pasta])
    }

    @Test("opening a page already on the stack pops back to it")
    func reopeningPopsBack() {
        var tabs = CompactTabNavigation()
        tabs.apply(.recipes)
        tabs.apply(pasta)
        tabs.apply(.profile(identifier: "ari"))
        tabs.apply(.cookbookDetail(id: "weeknights"))
        tabs.apply(pasta)
        #expect(tabs.path(for: .recipes) == [pasta])
        #expect(tabs.route == pasta)
    }

    @Test("Settings, Chefs, imports and unknown links push onto the Kitchen")
    func kitchenPages() {
        var tabs = CompactTabNavigation(route: .shoppingList)
        tabs.apply(.settings)
        #expect(tabs.selectedTab == .kitchen)
        #expect(tabs.path(for: .kitchen) == [.settings])

        tabs.apply(.chefs)
        tabs.apply(.profile(identifier: "ari"))
        #expect(tabs.path(for: .kitchen) == [.settings, .chefs, .profile(identifier: "ari")])

        tabs.apply(.capture)
        tabs.apply(.unknownLink)
        #expect(tabs.path(for: .kitchen) == [.settings, .chefs, .profile(identifier: "ari"), .capture, .unknownLink])
    }

    @Test("cook mode covers the tabs and closing it returns to the recipe")
    func cookModeCoversTabs() {
        var tabs = CompactTabNavigation()
        tabs.apply(.recipes)
        tabs.apply(pasta)
        tabs.apply(pastaCook)
        #expect(tabs.fullScreenRoute == pastaCook)
        #expect(tabs.route == pastaCook)
        #expect(tabs.visibleRoute == pasta)
        #expect(tabs.path(for: .recipes) == [pasta])

        // Cook mode's close button opens the recipe, which is already underneath.
        tabs.apply(pasta)
        #expect(tabs.fullScreenRoute == nil)
        #expect(tabs.path(for: .recipes) == [pasta])

        // Cooking straight from the Kitchen leaves the recipe underneath once cook mode closes.
        tabs.apply(.kitchen)
        tabs.apply(pastaCook)
        #expect(tabs.path(for: .kitchen).isEmpty)
        tabs.apply(pasta)
        #expect(tabs.fullScreenRoute == nil)
        #expect(tabs.path(for: .kitchen) == [pasta])

        tabs.apply(pastaCook)
        #expect(tabs.dismissFullScreen() == pasta)
        #expect(tabs.fullScreenRoute == nil)
    }

    @Test("an editor the app navigates away from leaves the stack")
    func editorsLeaveTheStack() {
        var tabs = CompactTabNavigation(route: .shoppingList)
        tabs.apply(.recipeEditor(id: nil))
        #expect(tabs.path(for: .shopping) == [.recipeEditor(id: nil)])

        // Saving a new recipe opens My Recipes; Shopping must not keep the finished editor.
        tabs.apply(.recipes)
        #expect(tabs.selectedTab == .recipes)
        #expect(tabs.path(for: .shopping).isEmpty)

        // Saving an existing recipe returns to it.
        tabs.apply(pasta)
        tabs.apply(.recipeEditor(id: "pasta"))
        tabs.apply(.recipeCoverControls(id: "pasta"))
        #expect(tabs.path(for: .recipes) == [pasta, .recipeCoverControls(id: "pasta")])
        tabs.apply(pasta)
        #expect(tabs.path(for: .recipes) == [pasta])

        // Cook mode over an editor leaves the editor in place.
        tabs.apply(.recipeEditor(id: "pasta"))
        tabs.apply(pastaCook)
        tabs.apply(.recipeEditor(id: "pasta"))
        #expect(tabs.fullScreenRoute == nil)
        #expect(tabs.path(for: .recipes) == [pasta, .recipeEditor(id: "pasta")])
    }

    @Test("tab switches and pops report the route to write back, which then changes nothing")
    func userChangesRoundTrip() {
        var tabs = CompactTabNavigation()
        tabs.apply(pasta)
        tabs.apply(.cookbooks)
        tabs.apply(.cookbookDetail(id: "weeknights"))

        #expect(tabs.select(.kitchen) == pasta)
        #expect(tabs.selectedTab == .kitchen)
        let afterSelect = tabs
        tabs.apply(pasta)
        #expect(tabs == afterSelect)

        #expect(tabs.select(.cookbooks) == .cookbookDetail(id: "weeknights"))
        #expect(tabs.setPath([], for: .cookbooks) == .cookbooks)
        let afterPop = tabs
        tabs.apply(.cookbooks)
        #expect(tabs == afterPop)

        // A pop on a tab that is not selected leaves the shown route alone.
        #expect(tabs.setPath([], for: .kitchen) == .cookbooks)
        #expect(tabs.path(for: .kitchen).isEmpty)

        tabs.apply(pastaCook)
        #expect(tabs.select(.shopping) == .shoppingList)
        #expect(tabs.fullScreenRoute == nil)
    }
}
