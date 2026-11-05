import Testing
@testable import SpoonjoyCore

@Suite("Split detail navigation")
struct SplitDetailNavigationTests {
    private let pasta = AppRoute.recipeDetail(id: "pasta", presentation: .detail)
    private let pastaCook = AppRoute.recipeDetail(id: "pasta", presentation: .cook)
    private let ari = AppRoute.profile(identifier: "ari")

    @Test("a chef opened from Chefs is pushed, so it has a way back to Chefs")
    func chefPushesOntoChefs() {
        var detail = SplitDetailNavigation(route: .chefs)
        detail.apply(ari)
        #expect(detail.root == .chefs)
        #expect(detail.path == [ari])
        #expect(detail.canGoBack)
        #expect(detail.goBack() == .chefs)
        #expect(!detail.canGoBack)
    }

    @Test("pages opened from pages stack up, and a back tap pops one")
    func pagesStack() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        detail.apply(ari)
        #expect(detail.path == [pasta, ari])
        #expect(detail.setPath([pasta]) == pasta)
    }

    @Test("a sidebar destination replaces the stack with its root")
    func sidebarResets() {
        var detail = SplitDetailNavigation(route: .chefs)
        detail.apply(ari)
        detail.apply(.cookbooks)
        #expect(detail.root == .cookbooks)
        #expect(detail.path.isEmpty)
    }

    @Test("opening a page already in the stack pops back to it")
    func reopenPops() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        detail.apply(ari)
        detail.apply(pasta)
        #expect(detail.path == [pasta])
    }

    @Test("cook mode leaves the stack underneath alone")
    func cookKeepsStack() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        detail.apply(pastaCook)
        #expect(detail.path == [pasta])
        detail.apply(pasta)
        #expect(detail.path == [pasta])
    }

    @Test("a finished editor leaves the stack")
    func editorLeaves() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        detail.apply(.recipeEditor(id: "pasta"))
        detail.apply(pasta)
        #expect(detail.path == [pasta])
    }

    @Test("a restored page starts on top of the Kitchen, so it has a way back")
    func restoredPageHasBack() {
        let detail = SplitDetailNavigation(route: pasta)
        #expect(detail.root == .kitchen)
        #expect(detail.path == [pasta])
    }

    @Test("the sidebar keeps its selection while pages are pushed, so the split view does not pop them")
    func sidebarSelectionHoldsDuringPushes() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        #expect(detail.sidebarRoute == .kitchen)
        detail.apply(.cookbooks)
        detail.apply(.cookbookDetail(id: "weeknights"))
        #expect(detail.sidebarRoute == .cookbooks)
    }

    @Test("a cookbook chosen in the sidebar is its own root")
    func sidebarCookbookIsRoot() {
        var detail = SplitDetailNavigation(route: .chefs)
        detail.showRoot(.cookbookDetail(id: "weeknights"))
        detail.apply(.cookbookDetail(id: "weeknights"))
        #expect(detail.root == .cookbookDetail(id: "weeknights"))
        #expect(detail.path.isEmpty)
        detail.apply(pasta)
        #expect(detail.path == [pasta])
        #expect(detail.sidebarRoute == .cookbookDetail(id: "weeknights"))
        // Opening that cookbook again (a link to it, say) pops back to it.
        detail.apply(.cookbookDetail(id: "weeknights"))
        #expect(detail.path.isEmpty)
    }

    @Test("an editor on top takes no back gesture or ⌘[, so its draft is never dropped")
    func editorBlocksBack() {
        var detail = SplitDetailNavigation(route: .kitchen)
        detail.apply(pasta)
        #expect(!detail.showsEditor)
        detail.apply(.recipeEditor(id: "pasta"))
        #expect(detail.showsEditor)
    }

    @Test("coming back to the split view keeps a stack that still ends on the route, and starts afresh otherwise")
    func resumedStack() {
        var detail = SplitDetailNavigation(route: .cookbooks)
        detail.apply(.cookbookDetail(id: "weeknights"))
        detail.apply(pasta)
        #expect(detail.resumed(at: pasta) == detail)
        #expect(detail.resumed(at: pastaCook) == detail)
        let fresh = detail.resumed(at: ari)
        #expect(fresh.root == .kitchen)
        #expect(fresh.path == [ari])
    }
}
