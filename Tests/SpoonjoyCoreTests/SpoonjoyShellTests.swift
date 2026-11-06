import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Spoonjoy shell")
struct SpoonjoyShellTests {
    private let pasta = AppRoute.recipeDetail(id: "pasta", presentation: .detail)
    private let pastaCook = AppRoute.recipeDetail(id: "pasta", presentation: .cook)

    @Test("opening a recipe from the Kitchen pushes it on the Kitchen's stack, and back pops it")
    func openAndGoBack() {
        var shell = SpoonjoyShell()
        #expect(!shell.canGoBack)
        let moved1 = shell.goBack()
        #expect(!moved1, "the Kitchen's root has no way back")
        shell.openRecipe("pasta")
        #expect(shell.route == pasta)
        #expect(shell.compactTabs.path(for: .kitchen) == [pasta])
        #expect(shell.canGoBack)
        let moved2 = shell.goBack()
        #expect(moved2)
        #expect(shell.route == .kitchen)
        #expect(shell.compactTabs.path(for: .kitchen).isEmpty)
    }

    @Test("cook mode covers the tabs and closes back to its recipe; it has no back of its own")
    func cookCoverAndClose() {
        var shell = SpoonjoyShell()
        shell.openRecipe("pasta")
        shell.startCooking("pasta")
        #expect(shell.route == pastaCook)
        #expect(shell.compactTabs.fullScreenRoute == pastaCook)
        #expect(!shell.canGoBack, "cook mode closes with its own Close")
        shell.closeCook("pasta")
        #expect(shell.route == pasta)
        #expect(shell.compactTabs.fullScreenRoute == nil)
    }

    @Test("each tab keeps its own stack, and a tab tap restores what it showed")
    func tabsKeepTheirStacks() {
        var shell = SpoonjoyShell()
        shell.openRecipe("pasta")
        let moved3 = shell.select(.recipes)
        #expect(!moved3)
        #expect(shell.route == .recipes)
        let moved4 = shell.select(.kitchen)
        #expect(!moved4)
        #expect(shell.route == pasta, "the Kitchen still shows the recipe it was left on")
        let moved5 = shell.select(.kitchen)
        #expect(!moved5, "re-selecting the same tab changes nothing")
        #expect(shell.route == pasta)
    }

    @Test("the search tab at its root asks the shell to run the search; deeper, it doesn't")
    func searchTabRunsTheSearch() {
        var shell = SpoonjoyShell()
        let moved6 = shell.select(.search)
        #expect(moved6)
        shell.navigate(to: .cookbookDetail(id: "book"))
        let moved7 = shell.select(.search)
        #expect(!moved7, "the search tab has a page pushed")
    }

    @Test("an editor leaves only through Cancel or Save, so it offers no back")
    func editorHasNoBack() {
        var shell = SpoonjoyShell()
        shell.openRecipe("pasta")
        shell.navigate(to: .recipeEditor(id: "pasta"))
        #expect(!shell.canGoBack)
        let moved8 = shell.goBack()
        #expect(!moved8)
        shell.navigate(to: .recipeCoverControls(id: "pasta"))
        #expect(!shell.canGoBack)
    }

    @Test("a blank editor route is the Add a recipe sheet, which no tab pushes")
    func blankEditorIsASheet() {
        var shell = SpoonjoyShell()
        shell.navigate(to: .recipeEditor(id: nil))
        #expect(shell.route == .recipeEditor(id: nil))
        #expect(shell.compactTabs.route == .kitchen)
    }

    @Test("setPath is the back swipe: the route follows the stack")
    func setPathFollows() {
        var shell = SpoonjoyShell()
        shell.openRecipe("pasta")
        shell.setPath([], for: .kitchen)
        #expect(shell.route == .kitchen)
        shell.setPath([], for: .kitchen)
        #expect(shell.route == .kitchen, "an unchanged stack leaves the route alone")
    }

    @Test("a cookbook opens on the tab it was tapped from")
    func cookbookOpens() {
        var shell = SpoonjoyShell(route: .kitchen)
        shell.openCookbook("book")
        #expect(shell.route == .cookbookDetail(id: "book"))
        #expect(shell.compactTabs.selectedTab == .kitchen)
        #expect(shell.compactTabs.path(for: .kitchen) == [.cookbookDetail(id: "book")])
    }

    @Test("the view's storage round-trips through the shell")
    func storageRoundTrip() {
        var navigation = AppNavigationState()
        navigation.navigate(to: pasta)
        var tabs = CompactTabNavigation()
        tabs.apply(pasta)
        var shell = SpoonjoyShell(navigation: navigation, compactTabs: tabs)
        shell.followRoute()
        #expect(shell.navigation == navigation)
        #expect(shell.compactTabs == tabs)
    }

    @Test("the tab bar's Cooking now switcher shows off the Kitchen's root, and only with a cook on the go")
    func cookingNowSwitcher() {
        var shell = SpoonjoyShell()
        #expect(!shell.showsCookingNowSwitcher(hasCooks: true), "the Kitchen's strip does the job there")
        shell.openRecipe("pasta")
        #expect(shell.showsCookingNowSwitcher(hasCooks: true), "a page pushed on the Kitchen carries it")
        #expect(!shell.showsCookingNowSwitcher(hasCooks: false))
        shell.select(.recipes)
        #expect(shell.showsCookingNowSwitcher(hasCooks: true))
    }

    // MARK: Cook mode

    private static let stamp = "2026-11-05T00:00:00Z"

    private static func recipe(firstDuration: Int? = 10, firstIngredients: [String] = ["lemon", "salt"]) -> Recipe {
        let url = URL(string: "https://spoonjoy.app/recipes/pasta")!
        return Recipe(
            id: "pasta",
            title: "Pasta",
            description: "Pasta.",
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/pasta",
            canonicalURL: url,
            attribution: RecipeAttribution(creditText: "By ari", canonicalURL: url, sourceURLRaw: nil, sourceHost: nil, sourceRecipe: nil),
            createdAt: stamp,
            updatedAt: stamp,
            steps: [
                RecipeStep(
                    id: "step_1",
                    stepNum: 1,
                    stepTitle: "Zest",
                    description: "Zest the lemon.",
                    duration: firstDuration,
                    ingredients: firstIngredients.map { RecipeIngredient(id: $0, name: $0, quantity: 1, unit: nil) }
                ),
                RecipeStep(id: "step_2", stepNum: 2, stepTitle: "Serve", description: "Serve.", duration: nil, ingredients: [])
            ],
            cookbooks: [],
            recentSpoons: []
        )
    }

    @Test("cook mode opens on the saved progress, else on a fresh start")
    func cookProgressOpens() {
        let recipe = Self.recipe()
        let fresh = SpoonjoyShell.cookProgress(for: recipe, saved: nil, startedAt: Self.stamp)
        #expect(fresh == CookModeProgress.starting(recipe: recipe, startedAt: Self.stamp))
        let model = CookModeViewModel(recipe: recipe, progress: fresh)
        let turned = SpoonjoyShell.turnCookPage(model, forward: true, updatedAt: Self.stamp)
        #expect(SpoonjoyShell.cookProgress(for: recipe, saved: turned, startedAt: Self.stamp) == turned)
    }

    @Test("a page turn moves one step either way, as the view model's own")
    func pageTurns() {
        let recipe = Self.recipe()
        let start = CookModeProgress.starting(recipe: recipe, startedAt: Self.stamp)
        let next = SpoonjoyShell.turnCookPage(CookModeViewModel(recipe: recipe, progress: start), forward: true, updatedAt: Self.stamp)
        #expect(next.activeStepIndex == 1)
        let back = SpoonjoyShell.turnCookPage(CookModeViewModel(recipe: recipe, progress: next), forward: false, updatedAt: Self.stamp)
        #expect(back.activeStepIndex == 0)
    }

    @Test("checking the step's last ingredient starts its timer once, and an unrelated change starts none")
    func autoTimers() throws {
        let recipe = Self.recipe()
        let start = CookModeProgress.starting(recipe: recipe, startedAt: Self.stamp)
        let lemon = try SpoonjoyShell.checkIngredient(CookModeViewModel(recipe: recipe, progress: start), id: "lemon", checked: true, updatedAt: Self.stamp)
        #expect(lemon.checkedIngredientIDs == ["lemon"])
        #expect(SpoonjoyShell.timersToAutoStart(recipe: recipe, from: start, to: lemon, runningStepIDs: []).isEmpty, "salt is still unchecked")
        let both = try SpoonjoyShell.checkIngredient(CookModeViewModel(recipe: recipe, progress: lemon), id: "salt", checked: true, updatedAt: Self.stamp)
        let timers = SpoonjoyShell.timersToAutoStart(recipe: recipe, from: lemon, to: both, runningStepIDs: [])
        #expect(timers.map(\.stepID) == ["step_1"])
        #expect(SpoonjoyShell.timersToAutoStart(recipe: recipe, from: lemon, to: both, runningStepIDs: ["step_1"]).isEmpty, "never a second timer")
        let turned = SpoonjoyShell.turnCookPage(CookModeViewModel(recipe: recipe, progress: both), forward: true, updatedAt: Self.stamp)
        #expect(SpoonjoyShell.timersToAutoStart(recipe: recipe, from: both, to: turned, runningStepIDs: []).isEmpty, "a page turn checks nothing")
        let untimed = Self.recipe(firstDuration: nil)
        let untimedStart = CookModeProgress.starting(recipe: untimed, startedAt: Self.stamp)
        let all = try SpoonjoyShell.checkIngredient(
            CookModeViewModel(recipe: untimed, progress: try SpoonjoyShell.checkIngredient(CookModeViewModel(recipe: untimed, progress: untimedStart), id: "lemon", checked: true, updatedAt: Self.stamp)),
            id: "salt",
            checked: true,
            updatedAt: Self.stamp
        )
        #expect(SpoonjoyShell.timersToAutoStart(recipe: untimed, from: untimedStart, to: all, runningStepIDs: []).isEmpty, "a step with no duration has no timer")
    }

    @Test("progress saved before the recipe changed still auto-starts from the progress it has")
    func autoTimersFromStaleProgress() throws {
        let recipe = Self.recipe()
        func stale(_ checked: [String]) throws -> CookModeProgress {
            var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(CookModeProgress.starting(recipe: recipe, startedAt: Self.stamp))) as? [String: Any])
            json["stepIDs"] = ["step_2"]
            json["checkedIngredientIDs"] = checked
            return try JSONDecoder().decode(CookModeProgress.self, from: JSONSerialization.data(withJSONObject: json))
        }
        let timers = SpoonjoyShell.timersToAutoStart(recipe: recipe, from: try stale([]), to: try stale(["lemon", "salt"]), runningStepIDs: [])
        #expect(timers.count <= 1, "a step the saved progress doesn't know never starts two timers")
    }
}
